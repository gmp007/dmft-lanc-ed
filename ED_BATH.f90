MODULE ED_BATH
  USE SF_CONSTANTS, only: zero
  USE SF_IOTOOLS, only:free_unit,reg,file_length,txtfy
  USE SF_LINALG, only: eye,inv
  USE SF_MISC, only: assert_shape
  USE ED_INPUT_VARS
  USE ED_VARS_GLOBAL
  USE ED_AUX_FUNX
  implicit none

  private



  !##################################################################
  !
  !     USER BATH ROUTINES:
  !
  !##################################################################

  !Interface for user bath I/O operations: get,set,copy
  interface get_component_bath
     module procedure get_full_component_bath
     module procedure get_spin_component_bath
     module procedure get_spin_orb_component_bath
  end interface get_component_bath

  interface set_component_bath
     module procedure set_full_component_bath
     module procedure set_spin_component_bath
     module procedure set_spin_orb_component_bath
  end interface set_component_bath

  interface copy_component_bath
     module procedure copy_full_component_bath
     module procedure copy_spin_component_bath
     module procedure copy_spin_orb_component_bath
  end interface copy_component_bath

  public :: get_bath_dimension
  public :: check_bath_dimension
  public :: get_component_bath_dimension
  public :: get_spin_component_bath_dimension
  public :: get_orb_component_bath_dimension
  public :: get_spin_orb_component_bath_dimension
  public :: get_component_bath
  public :: set_component_bath
  public :: copy_component_bath

  !explicit symmetries:
  interface break_symmetry_bath
     module procedure break_symmetry_bath_site
     module procedure break_symmetry_bath_lattice
  end interface break_symmetry_bath
  public :: break_symmetry_bath              


  interface spin_symmetrize_bath
     module procedure spin_symmetrize_bath_site
     module procedure spin_symmetrize_bath_lattice
  end interface spin_symmetrize_bath
  public :: spin_symmetrize_bath

  interface orb_symmetrize_bath
     module procedure orb_symmetrize_bath_site
     module procedure orb_symmetrize_bath_lattice
  end interface orb_symmetrize_bath
  public :: orb_symmetrize_bath

  interface orb_equality_bath
     module procedure orb_equality_bath_site
     module procedure orb_equality_bath_lattice
  end interface orb_equality_bath
  public :: orb_equality_bath

  interface ph_trans_bath
     module procedure ph_trans_bath_site
     module procedure ph_trans_bath_lattice
  end interface ph_trans_bath
  public :: ph_trans_bath

  interface ph_symmetrize_bath
     module procedure ph_symmetrize_bath_site
     module procedure ph_symmetrize_bath_lattice
  end interface ph_symmetrize_bath
  public :: ph_symmetrize_bath


  !##################################################################
  !
  !     DMFT BATH ROUTINES:
  !
  !##################################################################
  !PUBLIC   = transparent to the final user
  !INTERNAL = opaque to the user but available for internal use in the code.
  !
  !DMFT BATH procedures:
  public :: allocate_dmft_bath               !INTERNAL (for effective_bath)
  public :: deallocate_dmft_bath             !INTERNAL (for effective_bath)
  public :: init_dmft_bath                   !INTERNAL (for effective_bath)
  public :: init_dmft_bath_mask              !INTERNAL (for effective_bath)
  public :: write_dmft_bath                  !INTERNAL (for effective_bath)
  public :: save_dmft_bath                   !INTERNAL (for effective_bath)
  public :: set_dmft_bath                    !INTERNAL (for effective_bath)
  public :: get_dmft_bath                    !INTERNAL (for effective_bath)
  !






contains


  !##################################################################
  !
  !     USER BATH ROUTINES:
  !
  !##################################################################
  include 'ED_BATH/user_aux.f90'



  !##################################################################
  !
  !     DMFT BATH ROUTINES:
  !
  !##################################################################
  include 'ED_BATH/dmft_aux.f90'



  !##################################################################
  !
  !     USER BATH CHECKS:
  !
  !##################################################################
  !+-------------------------------------------------------------------+
  !PURPOSE  : Check if the dimension of the bath array are consistent
  !+-------------------------------------------------------------------+
  function check_bath_dimension(bath_,Hloc_nn) result(bool)
    real(8),dimension(:)        :: bath_
    integer                     :: Ntrue
    logical                     :: bool
    real(8),optional,intent(in) :: Hloc_nn(:,:,:,:)
    if (present(Hloc_nn))then
       Ntrue = get_bath_dimension(one*Hloc_nn)
    else
       Ntrue = get_bath_dimension()
    endif
    bool  = ( size(bath_) == Ntrue )
  end function check_bath_dimension


  !+-----------------------------------------------------------------------------+!
  !PURPOSE:  check if the specified itype is consistent with the input parameters.
  !+-----------------------------------------------------------------------------+!
  subroutine check_type_bath(itype)
    integer :: itype
    if(itype<1.OR.itype>2)stop "check_type_bath error: itype!=1,2"
    return
  end subroutine check_type_bath

  !+-----------------------------------------------------------------------------+!
  !PURPOSE: check that the input array hsa the correct dimensions specified 
  ! for the choice of itype and possiblty ispin and/or iorb.
  !+-----------------------------------------------------------------------------+!
  subroutine assert_component_size_bath(array,itype,string1,string2)
    real(8),dimension(:,:,:) :: array
    integer                  :: itype
    character(len=*)         :: string1,string2
    integer                  :: Ndim(3)
    call check_type_bath(itype)
    select case(bath_type)
    case default
       Ndim=[Nspin,Norb,Nbath]
    case('hybrid')
       if(itype==1)then
          Ndim=[Nspin,1,Nbath]
       else
          Ndim=[Nspin,Norb,Nbath]
       endif
    end select
    call assert_shape(Array,Ndim,reg(string1),reg(string2))
  end subroutine assert_component_size_bath
  !
  subroutine assert_spin_component_size_bath(array,itype,string1,string2)
    real(8),dimension(:,:) :: array
    integer                  :: itype
    character(len=*)         :: string1,string2
    integer                  :: Ndim(2)
    call check_type_bath(itype)
    select case(bath_type)
    case default
       Ndim=[Norb,Nbath]
    case('hybrid')
       if(itype==1)then
          Ndim=[1,Nbath]
       else
          Ndim=[Norb,Nbath]
       endif
    end select
    call assert_shape(Array,Ndim,reg(string1),reg(string2))
  end subroutine assert_spin_component_size_bath
  !
  subroutine assert_orb_component_size_bath(array,itype,string1,string2)
    real(8),dimension(:,:) :: array
    integer                  :: itype
    character(len=*)         :: string1,string2
    integer                  :: Ndim(2)
    Ndim=[Nspin,Nbath]
    call assert_shape(Array,Ndim,reg(string1),reg(string2))
  end subroutine assert_orb_component_size_bath
  !
  subroutine assert_spin_orb_component_size_bath(array,itype,string1,string2)
    real(8),dimension(:) :: array
    integer              :: itype
    character(len=*)     :: string1,string2
    integer              :: Ndim
    Ndim=Nbath
    if(size(array)/=Nbath)stop "assert_spin_orb_component_size_bath error: size(array)!=Ndim"
  end subroutine assert_spin_orb_component_size_bath




END MODULE ED_BATH
