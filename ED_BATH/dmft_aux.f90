!+-------------------------------------------------------------------+
!PURPOSE  : Allocate the ED bath
!+-------------------------------------------------------------------+
subroutine allocate_dmft_bath(dmft_bath_)
  type(effective_bath) :: dmft_bath_
  if(dmft_bath_%status)call deallocate_dmft_bath(dmft_bath_)
  !
  select case(bath_type)
  case default
     !
     allocate(dmft_bath_%e(Nspin,Norb,Nbath))  !local energies of the bath
     allocate(dmft_bath_%v(Nspin,Norb,Nbath))  !same-spin hybridization 
     !
  case('hybrid')
     !
     allocate(dmft_bath_%e(Nspin,1,Nbath))     !local energies of the bath
     allocate(dmft_bath_%v(Nspin,Norb,Nbath))  !same-spin hybridization 
     !
  case('replica')
     !
     allocate(dmft_bath_%h(Nspin,Nspin,Norb,Norb,Nbath))     !replica hamilt of the bath
     allocate(dmft_bath_%vr(Nbath))                          !hybridization 
     allocate(dmft_bath_%mask(Nspin,Nspin,Norb,Norb))        !mask on components 
     !
  end select
  dmft_bath_%status=.true.
end subroutine allocate_dmft_bath




!+-------------------------------------------------------------------+
!PURPOSE  : Deallocate the ED bath
!+-------------------------------------------------------------------+
subroutine deallocate_dmft_bath(dmft_bath_)
  type(effective_bath) :: dmft_bath_
  if(allocated(dmft_bath_%e))   deallocate(dmft_bath_%e)
  if(allocated(dmft_bath_%v))   deallocate(dmft_bath_%v)
  if(allocated(dmft_bath_%vr))  deallocate(dmft_bath_%vr)
  if(allocated(dmft_bath_%h))   deallocate(dmft_bath_%h)
  if(allocated(dmft_bath_%mask))deallocate(dmft_bath_%mask)
  dmft_bath_%status=.false.
end subroutine deallocate_dmft_bath




!+------------------------------------------------------------------+
!PURPOSE  : Initialize the DMFT loop, builindg H parameters and/or 
!reading previous (converged) solution
!+------------------------------------------------------------------+
subroutine init_dmft_bath(dmft_bath_)
  type(effective_bath) :: dmft_bath_
  real(8)              :: hrep_aux(Nspin*Norb,Nspin*Norb)
  real(8)              :: hybr_aux_R,hybr_aux_I
  real(8)              :: hrep_aux_R(Nspin*Norb,Nspin*Norb)
  real(8)              :: hrep_aux_I(Nspin*Norb,Nspin*Norb)
  real(8)              :: re,im
  integer              :: i,unit,flen,Nh
  integer              :: io,jo,iorb,ispin,jorb,jspin
  logical              :: IOfile
  real(8)              :: de,noise_tot
  real(8),allocatable  :: noise_b(:)
  character(len=21)    :: space
  if(.not.dmft_bath_%status)stop "init_dmft_bath error: bath not allocated"
  !
  allocate(noise_b(Nbath));noise_b=0.d0 
  call random_number(noise_b)
  noise_b=noise_b*ed_bath_noise_thr
  !
  select case(bath_type)
  case default
     !Get energies:
     dmft_bath_%e(:,:,1)    =-hwband + noise_b(1)
     dmft_bath_%e(:,:,Nbath)= hwband + noise_b(Nbath)
     Nh=Nbath/2
     if(mod(Nbath,2)==0.and.Nbath>=4)then
        de=hwband/max(Nh-1,1)
        dmft_bath_%e(:,:,Nh)  = -1.d-1 + noise_b(Nh)
        dmft_bath_%e(:,:,Nh+1)=  1.d-1 + noise_b(Nh+1)
        do i=2,Nh-1
           dmft_bath_%e(:,:,i)   =-hwband + (i-1)*de  + noise_b(i)
           dmft_bath_%e(:,:,Nbath-i+1)= hwband - (i-1)*de + noise_b(Nbath-i+1)
        enddo
     elseif(mod(Nbath,2)/=0.and.Nbath>=3)then
        de=hwband/Nh
        dmft_bath_%e(:,:,Nh+1)= 0.0d0 + noise_b(Nh+1)
        do i=2,Nh
           dmft_bath_%e(:,:,i)        =-hwband + (i-1)*de + noise_b(i)
           dmft_bath_%e(:,:,Nbath-i+1)= hwband - (i-1)*de + noise_b(Nbath-i+1)
        enddo
     endif
     !Get spin-keep yhbridizations
     do i=1,Nbath
        dmft_bath_%v(:,:,i)=max(0.1d0,1.d0/sqrt(dble(Nbath)))+noise_b(i)
     enddo
     !
  case('replica')
     !BATH INITIALIZATION
     dmft_bath_%h=zero
     do i=1,Nbath
        !
        dmft_bath_%h(:,:,:,:,i)=impHloc-(xmu+noise_b(i))*so2nn_reshape(eye(Nspin*Norb),Nspin,Norb)
        !
     enddo
     !HYBR. INITIALIZATION
     dmft_bath_%vr=zero
     do i=1,Nbath
        noise_tot=noise_b(i)
        dmft_bath_%vr(i)=0.5d0+noise_b(i)!*(-1)**(i-1)
     enddo
     !
     deallocate(noise_b)
     !
  end select
  !
  !
  !
  !Read from file if exist:
  !
  inquire(file=trim(Hfile)//trim(ed_file_suffix)//".restart",exist=IOfile)
  if(IOfile)then
     write(LOGfile,"(A)")'Reading bath from file'//trim(Hfile)//trim(ed_file_suffix)//".restart"
     unit = free_unit()
     flen = file_length(trim(Hfile)//trim(ed_file_suffix)//".restart")
     !
     open(unit,file=trim(Hfile)//trim(ed_file_suffix)//".restart")
     !
     select case(bath_type)
     case default
        !
        read(unit,*)
        do i=1,min(flen,Nbath)
           read(unit,*)((&
                dmft_bath_%e(ispin,iorb,i),&
                dmft_bath_%v(ispin,iorb,i),&
                iorb=1,Norb),ispin=1,Nspin)
        enddo
        !
     case ('hybrid')
        read(unit,*)
        !
        do i=1,min(flen,Nbath)
           read(unit,*)(&
                dmft_bath_%e(ispin,1,i),&
                (&
                dmft_bath_%v(ispin,iorb,i),&
                iorb=1,Norb),&
                ispin=1,Nspin)
        enddo
        !
     case ('replica')
        !
        do i=1,Nbath
           hrep_aux_R=0.0d0;hrep_aux_I=0.0d0
           hybr_aux_R=0.0d0;hybr_aux_I=0.0d0
           hrep_aux=zero
           do io=1,Nspin*Norb
              if(io==1)read(unit,"(90(F21.12,1X))")hybr_aux_R,(hrep_aux_R(io,jo),jo=1,Nspin*Norb)
              if(io/=1)read(unit,"(2a21,90(F21.12,1X))")space,space,(hrep_aux_R(io,jo),jo=1,Nspin*Norb)
           enddo
           read(unit,*)
           hrep_aux=hrep_aux_R!cmplx(hrep_aux_R,hrep_aux_I)
           dmft_bath_%h(:,:,:,:,i)=so2nn_reshape(hrep_aux,Nspin,Norb)
           dmft_bath_%vr(i)=hybr_aux_R!cmplx(hybr_aux_R,hybr_aux_I)
        enddo
        !
        !
     end select
     close(unit)
  endif
end subroutine init_dmft_bath

!+-------------------------------------------------------------------+
!PURPOSE  : set the mask based on impHloc in the replica bath topology
!+-------------------------------------------------------------------+
subroutine init_dmft_bath_mask(dmft_bath_)
  type(effective_bath),intent(inout) :: dmft_bath_
  integer                            :: iorb,ispin,jorb,jspin
  integer                            :: io,jo
  !
  if(.not.(allocated(impHloc))) then
     stop "impHloc not allocated on mask initialization"
  endif
  dmft_bath_%mask=.false.
  !
  ! MASK INITIALIZATION
  !
  do ispin=1,Nspin
     do iorb=1,Norb
        !diagonal elements always present
        dmft_bath_%mask(ispin,ispin,iorb,iorb)=.true.
        !off-diagonal elements
        do jspin=1,Nspin
           do jorb=1,Norb
              io = iorb + (ispin-1)*Norb
              jo = jorb + (jspin-1)*Norb
              if(io/=jo)then
                 if( abs(impHloc(ispin,jspin,iorb,jorb)).gt.1e-6)&
                      dmft_bath_%mask(ispin,jspin,iorb,jorb)=.true.
              endif
           enddo
        enddo
     enddo
  enddo
  !
end subroutine init_dmft_bath_mask


!+-------------------------------------------------------------------+
!PURPOSE  : write out the bath to a given unit with 
! the following column formatting: 
! [(Ek_iorb,Vk_iorb)_iorb=1,Norb]_ispin=1,Nspin
!+-------------------------------------------------------------------+
subroutine write_dmft_bath(dmft_bath_,unit)
  type(effective_bath) :: dmft_bath_
  integer,optional     :: unit
  integer              :: unit_
  integer              :: i
  integer              :: io,jo,iorb,ispin
  real(8)              :: hybr_aux
  real(8)              :: hrep_aux(Nspin*Norb,Nspin*Norb)
  unit_=LOGfile;if(present(unit))unit_=unit
  if(.not.dmft_bath_%status)stop "write_dmft_bath error: bath not allocated"
  select case(bath_type)
  case default
     !
     write(unit_,"(90(A21,1X))")&
          ((&
          "#Ek_l"//reg(txtfy(iorb))//"_s"//reg(txtfy(ispin)),&
          "Vk_l"//reg(txtfy(iorb))//"_s"//reg(txtfy(ispin)),&
          iorb=1,Norb),ispin=1,Nspin)
     do i=1,Nbath
        write(unit_,"(90(F21.12,1X))")((&
             dmft_bath_%e(ispin,iorb,i),&
             dmft_bath_%v(ispin,iorb,i),&
             iorb=1,Norb),ispin=1,Nspin)
     enddo
     !
  case('hybrid')
     !
     write(unit_,"(90(A21,1X))")(&
          "#Ek_s"//reg(txtfy(ispin)),&
          ("Vk_l"//reg(txtfy(iorb))//"_s"//reg(txtfy(ispin)),iorb=1,Norb),&
          ispin=1,Nspin)
     do i=1,Nbath
        write(unit_,"(90(F21.12,1X))")(&
             dmft_bath_%e(ispin,1,i),&
             (dmft_bath_%v(ispin,iorb,i),iorb=1,Norb),&
             ispin=1,Nspin)
     enddo
     !
  case ('replica')
     !
     do i=1,Nbath
        hrep_aux=0d0
        hrep_aux=nn2so_reshape(dmft_bath_%h(:,:,:,:,i),Nspin,Norb)
        hybr_aux=dmft_bath_%vr(i)
        do io=1,Nspin*Norb
           if(unit_==LOGfile)then
              if(io==1) write(unit_,"(F9.4,a5,90(F9.4,1X))")hybr_aux,"|",( hrep_aux(io,jo),jo=1,Nspin*Norb)
              if(io/=1) write(unit_,"(A9  ,a5,90(F9.4,1X))") "  "   ,"|",( hrep_aux(io,jo),jo=1,Nspin*Norb)
           else
              if(io==1)write(unit_,"(90(F21.12,1X))")hybr_aux,(hrep_aux(io,jo),jo=1,Nspin*Norb)
              if(io/=1)write(unit_,"(a21,90(F21.12,1X))")"  ",(hrep_aux(io,jo),jo=1,Nspin*Norb)
           endif
        enddo
        write(unit_,*)
     enddo
     !
  end select
end subroutine write_dmft_bath






!+-------------------------------------------------------------------+
!PURPOSE  : save the bath to a given file using the write bath
! procedure and formatting: 
!+-------------------------------------------------------------------+
subroutine save_dmft_bath(dmft_bath_,file,used)
  type(effective_bath)      :: dmft_bath_
  character(len=*),optional :: file
  character(len=256)        :: file_
  logical,optional          :: used
  logical                   :: used_
  character(len=16)         :: extension
  integer                   :: unit_
  ! if(ED_MPI_ID==0)then
  if(.not.dmft_bath_%status)stop "save_dmft_bath error: bath is not allocated"
  used_=.false.;if(present(used))used_=used
  extension=".restart";if(used_)extension=".used"
  file_=str(str(Hfile)//str(ed_file_suffix)//str(extension))
  if(present(file))file_=str(file)
  unit_=free_unit()
  open(unit_,file=str(file_))
  call write_dmft_bath(dmft_bath_,unit_)
  close(unit_)
  ! endif
end subroutine save_dmft_bath




!+-------------------------------------------------------------------+
!PURPOSE  : set the bath components from a given user provided 
! bath-array 
!+-------------------------------------------------------------------+
subroutine set_dmft_bath(bath_,dmft_bath_)
  real(8),dimension(:)   :: bath_
  type(effective_bath)   :: dmft_bath_
  integer                :: stride,io,jo,i
  integer                :: iorb,ispin,jorb,jspin,ibath,maxspin
  logical                :: check
  real(8)                :: hrep_aux(Nspin*Norb,Nspin*Norb)
  real(8)                :: element_R,eps_k,lambda_k
  if(.not.dmft_bath_%status)stop "set_dmft_bath error: bath not allocated"
  check = check_bath_dimension(bath_)
  if(.not.check)stop "set_dmft_bath error: wrong bath dimensions"
  !
  select case(bath_type)
  case default
     !
     stride = 0
     do ispin=1,Nspin
        do iorb=1,Norb
           do i=1,Nbath
              io = stride + i + (iorb-1)*Nbath + (ispin-1)*Nbath*Norb
              dmft_bath_%e(ispin,iorb,i) = bath_(io)
           enddo
        enddo
     enddo
     stride = Nspin*Norb*Nbath
     do ispin=1,Nspin
        do iorb=1,Norb
           do i=1,Nbath
              io = stride + i + (iorb-1)*Nbath + (ispin-1)*Nbath*Norb
              dmft_bath_%v(ispin,iorb,i) = bath_(io)
           enddo
        enddo
     enddo
     !
     !
  case ('hybrid')
     !
     stride = 0
     do ispin=1,Nspin
        do i=1,Nbath
           io = stride + i + (ispin-1)*Nbath
           dmft_bath_%e(ispin,1,i) = bath_(io)
        enddo
     enddo
     stride = Nspin*Nbath
     do ispin=1,Nspin
        do iorb=1,Norb
           do i=1,Nbath
              io = stride + i + (iorb-1)*Nbath + (ispin-1)*Norb*Nbath
              dmft_bath_%v(ispin,iorb,i) = bath_(io)
           enddo
        enddo
     enddo
     !
     !
  case ('replica')
     !
     dmft_bath_%h=0d0
     dmft_bath_%vr=0d0
     i = 0
     !all non-vanishing terms in imploc - all spin
     do ispin=1,Nspin
        do iorb=1,Norb
           do jorb=1,Norb
              do ibath=1,Nbath
                 io = iorb + (ispin-1)*Norb
                 jo = jorb + (ispin-1)*Norb
                 if(io.gt.jo)cycle!only diagonal and upper triangular are saved by symmetry
                 element_R=0d0
                 if(dmft_bath_%mask(ispin,ispin,iorb,jorb)) then
                    i=i+1
                    element_R=bath_(i)
                 endif
                 dmft_bath_%h(ispin,ispin,iorb,jorb,ibath)=element_R
                 !symmetry
                 if(iorb/=jorb)dmft_bath_%h(ispin,ispin,jorb,iorb,ibath)=dmft_bath_%h(ispin,ispin,iorb,jorb,ibath)
              enddo
           enddo
        enddo
     enddo
     !
     !all Re[Hybr]
     do ibath=1,Nbath
        i=i+1
        dmft_bath_%vr(ibath)=bath_(i)
     enddo
     !
     !
  end select
end subroutine set_dmft_bath



!+-------------------------------------------------------------------+
!PURPOSE  : copy the bath components back to a 1-dim array 
!+-------------------------------------------------------------------+
subroutine get_dmft_bath(dmft_bath_,bath_)
  type(effective_bath)   :: dmft_bath_
  real(8),dimension(:)   :: bath_
  real(8)                :: hrep_aux(Nspin*Norb,Nspin*Norb)
  integer                :: stride,io,jo,i
  integer                :: iorb,ispin,jorb,jspin,ibath,maxspin
  logical                :: check
  if(.not.dmft_bath_%status)stop "get_dmft_bath error: bath not allocated"
  check=check_bath_dimension(bath_)
  if(.not.check)stop "get_dmft_bath error: wrong bath dimensions"
  !
  select case(bath_type)
  case default
     !
     stride = 0
     do ispin=1,Nspin
        do iorb=1,Norb
           do i=1,Nbath
              io = stride + i + (iorb-1)*Nbath + (ispin-1)*Nbath*Norb
              bath_(io) = dmft_bath_%e(ispin,iorb,i) 
           enddo
        enddo
     enddo
     stride = Nspin*Norb*Nbath
     do ispin=1,Nspin
        do iorb=1,Norb
           do i=1,Nbath
              io = stride + i + (iorb-1)*Nbath + (ispin-1)*Nbath*Norb
              bath_(io) = dmft_bath_%v(ispin,iorb,i)
           enddo
        enddo
     enddo
     !
     !
  case ('hybrid')
     !
     stride = 0
     do ispin=1,Nspin
        do i=1,Nbath
           io = stride + i + (ispin-1)*Nbath
           bath_(io) =  dmft_bath_%e(ispin,1,i)
        enddo
     enddo
     stride = Nspin*Nbath
     do ispin=1,Nspin
        do iorb=1,Norb
           do i=1,Nbath
              io = stride + i + (iorb-1)*Nbath + (ispin-1)*Norb*Nbath
              bath_(io) =  dmft_bath_%v(ispin,iorb,i)
           enddo
        enddo
     enddo
     !
     !
  case ('replica')
     !
     i = 0
     !all non-vanishing terms in imploc - all spin
     do ispin=1,Nspin
        do iorb=1,Norb
           do jorb=1,Norb
              do ibath=1,Nbath
                 io = iorb + (ispin-1)*Norb
                 jo = jorb + (ispin-1)*Norb
                 if(io.gt.jo)cycle !only diagonal and upper triangular are saved by symmetry
                 if(dmft_bath_%mask(ispin,ispin,iorb,jorb)) then
                    i=i+1
                    bath_(i)=dmft_bath_%h(ispin,ispin,iorb,jorb,ibath)
                 endif
              enddo
           enddo
        enddo
     enddo
     !
     !all Re[Hybr]
     do ibath=1,Nbath
        i=i+1
        bath_(i)=dmft_bath_%vr(ibath)
     enddo
     !    
     !
  end select
end subroutine get_dmft_bath



