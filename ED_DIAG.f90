!########################################################################
!PURPOSE  : Diagonalize the Effective Impurity Problem
!|{ImpUP1,...,ImpUPN},BathUP>|{ImpDW1,...,ImpDWN},BathDW>
!########################################################################
module ED_DIAG
  USE SF_CONSTANTS
  USE SF_LINALG, only: eigh
  USE SF_TIMER,  only: start_timer,stop_timer,eta
  USE SF_IOTOOLS, only:reg,free_unit
  USE SF_STAT
  USE SF_SP_LINALG
  !
  USE ED_INPUT_VARS
  USE ED_VARS_GLOBAL
  USE ED_EIGENSPACE
  USE ED_SETUP
  USE ED_HAMILTONIAN
  !
#ifdef _MPI
  USE MPI
  USE SF_MPI
#endif
  implicit none
  private


  public :: diagonalize_impurity

  public :: ed_diag_set_MPI
  public :: ed_diag_del_MPI

  !> MPI local variables (shared)
#ifdef _MPI
  integer :: MpiComm=MPI_UNDEFINED
#else
  integer :: MpiComm=0
#endif
  logical :: MpiStatus=.false.
  integer :: Mpi_Size=1
  integer :: Mpi_Rank=0
  logical :: Mpi_Master=.true.  !
  integer :: Mpi_Ierr

  integer :: unit

contains



  !+-------------------------------------------------------------------+
  !PURPOSE  : Setup the MPI-Parallel environment for ED_DIAG
  !+------------------------------------------------------------------+
  subroutine ed_diag_set_MPI(comm)
#ifdef _MPI
    integer :: comm
    MpiComm  = comm
    MpiStatus = .true.
    Mpi_Size  = get_Size_MPI(MpiComm)
    Mpi_Rank  = get_Rank_MPI(MpiComm)
    Mpi_Master= get_Master_MPI(MpiComm)
#else
    integer,optional :: comm
#endif
  end subroutine ed_diag_set_MPI

  subroutine ed_diag_del_MPI()
#ifdef _MPI
    MpiComm  = MPI_UNDEFINED
    MpiStatus = .false.
#endif
  end subroutine ed_diag_del_MPI





  !+-------------------------------------------------------------------+
  !PURPOSE  : Setup the Hilbert space, create the Hamiltonian, get the
  ! GS, build the Green's functions calling all the necessary routines
  !+------------------------------------------------------------------+
  subroutine diagonalize_impurity()
    call ed_diag_c
    call ed_analysis
  end subroutine diagonalize_impurity







  !+-------------------------------------------------------------------+
  !PURPOSE  : diagonalize the Hamiltonian in each sector and find the 
  ! spectrum DOUBLE PRECISION
  !+------------------------------------------------------------------+
  subroutine ed_diag_c
    integer             :: isector,Dim
    integer             :: Nups(Ns_Ud)
    integer             :: Ndws(Ns_Ud)
    integer             :: i,j,iter,unit,vecDim
    integer             :: Nitermax,Neigen,Nblock
    real(8)             :: oldzero,enemin,Ei
    real(8),allocatable :: eig_values(:)
    real(8),allocatable :: eig_basis(:,:)
    logical             :: lanc_solve,Tflag,lanc_verbose,bool

    !
    if(state_list%status)call es_delete_espace(state_list)
    state_list=es_init_espace()
    oldzero=1000.d0
    if(MPI_MASTER)then
       write(LOGfile,"(A)")"Diagonalize impurity H:"
       call start_timer()
    endif
    !
    lanc_verbose=.false.
    if(ed_verbose>2)lanc_verbose=.true.
    !
    iter=0
    sector: do isector=1,Nsectors
       if(.not.twin_mask(isector))cycle sector !cycle loop if this sector should not be investigated
       iter=iter+1
       call get_Nup(isector,nups)
       call get_Ndw(isector,ndws)
       Tflag    = twin_mask(isector).AND.ed_twin
       bool=.true.
       do i=1,Ns_ud
          Bool=Bool.AND.(nups(i)/=ndws(i))
       enddo
       Tflag=Tflag.AND.Bool
       !
       Dim      = getdim(isector)
       !
       Neigen   = min(dim,neigen_sector(isector))
       Nitermax = min(dim,lanc_niter)
       Nblock   = min(dim,lanc_ncv_factor*max(Neigen,lanc_nstates_sector) + lanc_ncv_add)
       !
       !
       lanc_solve  = .true.
       if(Neigen==dim)lanc_solve=.false.
       if(dim<=max(lanc_dim_threshold,MPI_SIZE))lanc_solve=.false.
       !
       if(MPI_MASTER)then
          if(ed_verbose>=3)then
             if(lanc_solve)then
                write(LOGfile,"(1X,I4,A,I4,A6,"//str(Ns_Ud)//"I3,A6,"//str(Ns_Ud)//"I3,A6,I15,A12,3I6)")&
                     iter,"-Solving sector:",isector,", nup:",nups,", ndw:",ndws,", dim=",&
                     getdim(isector),", Lanc Info:",Neigen,Nitermax,Nblock
             else
                write(LOGfile,"(1X,I4,A,I4,A6,"//str(Ns_Ud)//"I3,A6,"//str(Ns_Ud)//"I3,A6,I15)")&
                     iter,"-Solving sector:",isector,", nup:",nups,", ndw:",ndws,", dim=",&
                     getdim(isector)
             endif
          elseif(ed_verbose==1.OR.ed_verbose==2)then
             call eta(iter,count(twin_mask),LOGfile)
          endif
       endif
       !
       !
       if(allocated(eig_values))deallocate(eig_values)
       if(allocated(eig_basis))deallocate(eig_basis)
       if(lanc_solve)then
          allocate(eig_values(Neigen))
          eig_values=0d0 
          !
          vecDim = vecDim_Hv_sector(isector)
          allocate(eig_basis(vecDim,Neigen))
          eig_basis=zero
          !
          call build_Hv_sector(isector)
          !
#ifdef _MPI
          if(MpiStatus)then
             call sp_eigh(MpiComm,spHtimesV_p,Dim,Neigen,Nblock,Nitermax,eig_values,eig_basis,&
                  tol=lanc_tolerance,&
                  iverbose=(ed_verbose>3))
          else
             call sp_eigh(spHtimesV_p,Dim,Neigen,Nblock,Nitermax,eig_values,eig_basis,&
                  tol=lanc_tolerance,&
                  iverbose=(ed_verbose>3))
          endif
#else
          call sp_eigh(spHtimesV_p,Dim,Neigen,Nblock,Nitermax,eig_values,eig_basis,&
               tol=lanc_tolerance,&
               iverbose=(ed_verbose>3))
#endif
          call delete_Hv_sector()
       else
          allocate(eig_values(Dim))
          eig_values=0d0
          !
          vecDim = Dim
          allocate(eig_basis(Dim,Dim))
          eig_basis=0d0
          !
          call build_Hv_sector(isector,eig_basis)
          call eigh(eig_basis,eig_values,'V','U')
          if(dim==1)eig_basis(dim,dim)=one
          !
          call delete_Hv_sector()
       endif
       if(ed_verbose>=4)write(LOGfile,*)"EigValues: ",eig_values(:Neigen)
       !
       if(finiteT)then
          do i=1,Neigen
             call es_add_state(state_list,eig_values(i),eig_basis(:,i),isector,twin=Tflag,size=lanc_nstates_total)
          enddo
       else
          do i=1,Neigen
             enemin = eig_values(i)
             if (enemin < oldzero-10.d0*gs_threshold)then
                oldzero=enemin
                call es_free_espace(state_list)
                call es_add_state(state_list,enemin,eig_basis(:,i),isector,twin=Tflag)
             elseif(abs(enemin-oldzero) <= gs_threshold)then
                oldzero=min(oldzero,enemin)
                call es_add_state(state_list,enemin,eig_basis(:,i),isector,twin=Tflag)
             endif
          enddo
       endif
       !
       if(MPI_MASTER)then
          unit=free_unit()
          open(unit,file="eigenvalues_list"//reg(ed_file_suffix)//".ed",position='append',action='write')
          call print_eigenvalues_list(isector,eig_values(1:Neigen),unit,lanc_solve)
          close(unit)
       endif
       !
       if(allocated(eig_values))deallocate(eig_values)
       if(allocated(eig_basis))deallocate(eig_basis)
       !
    enddo sector
    if(MPI_MASTER)call stop_timer(LOGfile)
  end subroutine ed_diag_c










  !###################################################################################################
  !
  !    POST-PROCESSING ROUTINES
  !
  !###################################################################################################
  !+-------------------------------------------------------------------+
  !PURPOSE  : analyse the spectrum and print some information after 
  !lanczos diagonalization. 
  !+------------------------------------------------------------------+
  subroutine ed_analysis()
    integer             :: nup,ndw,sz,n,isector,dim
    integer             :: istate
    integer             :: i,unit
    integer             :: nups(Ns_Ud),ndws(Ns_Ud)
    integer             :: Nsize,NtoBremoved,nstates_below_cutoff
    integer             :: numgs
    real(8)             :: Egs,Ei,Ec,Etmp
    type(histogram)     :: hist
    real(8)             :: hist_a,hist_b,hist_w
    integer             :: hist_n
    integer,allocatable :: list_sector(:),count_sector(:)    
    !POST PROCESSING:
    if(MPI_MASTER)then
       open(free_unit(unit),file="state_list"//reg(ed_file_suffix)//".ed")
       call save_state_list(unit)
       close(unit)
    endif
    if(ed_verbose>=2)call print_state_list(LOGfile)
    !
    zeta_function=0d0
    Egs = state_list%emin
    if(finiteT)then
       do i=1,state_list%size
          ei   = es_return_energy(state_list,i)
          zeta_function = zeta_function + exp(-beta*(Ei-Egs))
       enddo
    else
       zeta_function=real(state_list%size,8)
    end if
    !
    !
    numgs=es_return_gs_degeneracy(state_list,gs_threshold)
    if(numgs>Nsectors)stop "ed_diag: too many gs"
    if(MPI_MASTER.AND.ed_verbose>=2)then
       do istate=1,numgs
          isector = es_return_sector(state_list,istate)
          Egs     = es_return_energy(state_list,istate)
          call get_Nup(isector,Nups)
          call get_Ndw(isector,Ndws)
          write(LOGfile,"(A,F20.12,"//str(Ns_Ud)//"I4,"//str(Ns_Ud)//"I4)")'Egs =',Egs,nups,ndws
       enddo
       write(LOGfile,"(A,F20.12)")'Z   =',zeta_function
    endif
    !
    !
    !
    !get histogram distribution of the sector contributing to the evaluated spectrum:
    !go through states list and update the neigen_sector(isector) sector-by-sector
    if(finiteT)then
       if(MPI_MASTER)then
          unit=free_unit()
          open(unit,file="histogram_states"//reg(ed_file_suffix)//".ed",position='append')
          hist_n = Nsectors
          hist_a = 1d0
          hist_b = dble(Nsectors)
          hist_w = 1d0
          hist = histogram_allocate(hist_n)
          call histogram_set_range_uniform(hist,hist_a,hist_b)
          do i=1,state_list%size
             isector = es_return_sector(state_list,i)
             call histogram_accumulate(hist,dble(isector),hist_w)
          enddo
          call histogram_print(hist,unit)
          write(unit,*)""
          close(unit)
       endif
       !
       !
       !
       allocate(list_sector(state_list%size),count_sector(Nsectors))
       !get the list of actual sectors contributing to the list
       do i=1,state_list%size
          list_sector(i) = es_return_sector(state_list,i)
       enddo
       !count how many times a sector appears in the list
       do i=1,Nsectors
          count_sector(i) = count(list_sector==i)
       enddo
       !adapt the number of required Neig for each sector based on how many
       !appeared in the list.
       do i=1,Nsectors
          if(any(list_sector==i))then !if(count_sector(i)>1)then
             neigen_sector(i)=neigen_sector(i)+1
          else
             neigen_sector(i)=neigen_sector(i)-1
          endif
          !prevent Neig(i) from growing unbounded but 
          !try to put another state in the list from sector i
          if(neigen_sector(i) > count_sector(i))neigen_sector(i)=count_sector(i)+1
          if(neigen_sector(i) <= 0)neigen_sector(i)=1
       enddo
       !check if the number of states is enough to reach the required accuracy:
       !the condition to fullfill is:
       ! exp(-beta(Ec-Egs)) < \epsilon_c
       ! if this condition is violated then required number of states is increased
       ! if number of states is larger than those required to fullfill the cutoff: 
       ! trim the list and number of states.
       Egs  = state_list%emin
       Ec   = state_list%emax
       Nsize= state_list%size
       if(exp(-beta*(Ec-Egs)) > cutoff)then
          lanc_nstates_total=lanc_nstates_total + lanc_nstates_step
          if(MPI_MASTER)write(LOGfile,"(A,I4)")"Increasing lanc_nstates_total:",lanc_nstates_total
       else
          ! !Find the energy level beyond which cutoff condition is verified & cut the list to that size
          write(LOGfile,*)
          isector = es_return_sector(state_list,state_list%size)
          Ei      = es_return_energy(state_list,state_list%size)
          do while ( exp(-beta*(Ei-Egs)) <= cutoff )
             if(ed_verbose>=1.AND.MPI_MASTER)write(LOGfile,"(A,I4,I5)")"Trimming state:",isector,state_list%size
             call es_pop_state(state_list)
             isector = es_return_sector(state_list,state_list%size)
             Ei      = es_return_energy(state_list,state_list%size)
          enddo
          if(ed_verbose>=1.AND.MPI_MASTER)then
             write(LOGfile,*)"Trimmed state list:"          
             call print_state_list(LOGfile)
          endif
          !
          lanc_nstates_total=max(state_list%size,lanc_nstates_step)+lanc_nstates_step
          write(LOGfile,"(A,I4)")"Adjusting lanc_nstates_total to:",lanc_nstates_total
          !
       endif
    endif
  end subroutine ed_analysis


  subroutine print_state_list(unit)
    integer :: indices(2*Ns_Ud),isector
    integer :: istate
    integer :: unit
    real(8) :: Estate
    if(MPI_MASTER)then
       write(unit,"(A1,A6,A18,2x,A19,1x,2A10,A12)")"#","i","E_i","exp(-(E-E0)/T)","Sect","Dim","Indices:"
       do istate=1,state_list%size
          Estate  = es_return_energy(state_list,istate)
          isector = es_return_sector(state_list,istate)
          write(unit,"(i6,f18.12,2x,ES19.12,1x,2I10)",advance='no')&
               istate,Estate,exp(-beta*(Estate-state_list%emin)),isector,getdim(isector)
          call get_Indices(isector,Ns_Orb,Indices)
          write(unit,"("//str(2*Ns_Ud)//"I4)")Indices
       enddo
    endif
  end subroutine print_state_list


  subroutine save_state_list(unit)
    integer :: indices(2*Ns_Ud),isector
    integer :: istate
    integer :: unit
    if(MPI_MASTER)then
       do istate=1,state_list%size
          isector = es_return_sector(state_list,istate)
          call get_Indices(isector,Ns_Orb,Indices)
          write(unit,"(i8,i12,"//str(2*Ns_Ud)//"i8)")istate,isector,Indices
       enddo
    endif
  end subroutine save_state_list


  subroutine print_eigenvalues_list(isector,eig_values,unit,bool)
    integer              :: isector
    real(8),dimension(:) :: eig_values
    integer              :: unit,i,indices(2*Ns_Ud)
    logical              :: bool
    if(MPI_MASTER)then
       if(bool)then
          write(unit,"(A9,A15)")" # Sector","Indices"
       else
          write(unit,"(A10,A15)")" #X Sector","Indices"
       endif
       call get_Indices(isector,Ns_Orb,Indices)
       write(unit,"(I9,"//str(2*Ns_Ud)//"I6)")isector,Indices
       do i=1,size(eig_values)
          write(unit,*)eig_values(i)
       enddo
       write(unit,*)""
    endif
  end subroutine print_eigenvalues_list





end MODULE ED_DIAG









