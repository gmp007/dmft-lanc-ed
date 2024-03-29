!NORMAL, MATSUBARA GREEN'S FUNCTIONS
subroutine ed_get_g0imp_matsubara_1(Gmats)
  complex(8),dimension(Nspin,Nspin,Norb,Norb,Lmats),intent(inout) :: Gmats
  Gmats(:,:,:,:,:) = impG0mats(:,:,:,:,:)
end subroutine ed_get_g0imp_matsubara_1

subroutine ed_get_g0imp_matsubara_2(Gmats)
  complex(8),dimension(Nspin*Norb,Nspin*Norb,Lmats),intent(inout) :: Gmats
  integer  :: io,jo,iorb,jorb,ispin,jspin
  do ispin=1,Nspin
     do jspin=1,Nspin
        do iorb=1,Norb
           do jorb=1,Norb
              io = iorb + (ispin-1)*Norb
              jo = jorb + (jspin-1)*Norb
              Gmats(io,jo,:) = impG0mats(ispin,jspin,iorb,jorb,:)
           enddo
        enddo
     enddo
  enddo
end subroutine ed_get_g0imp_matsubara_2

subroutine ed_get_g0imp_matsubara_3(Gmats,ispin,jspin,iorb,jorb)
  complex(8),dimension(Lmats),intent(inout) :: Gmats
  integer                                   :: iorb,jorb,ispin,jspin
  Gmats(:) = impG0mats(ispin,jspin,iorb,jorb,:)
end subroutine ed_get_g0imp_matsubara_3








subroutine ed_get_g0imp_matsubara_lattice_1(Gmats,Nsites)
  integer                                                                :: Nsites
  complex(8),dimension(Nsites,Nspin,Nspin,Norb,Norb,Lmats),intent(inout) :: Gmats
  Gmats(1:Nsites,:,:,:,:,:) = G0matsii(1:Nsites,:,:,:,:,:)
end subroutine ed_get_g0imp_matsubara_lattice_1

subroutine ed_get_g0imp_matsubara_lattice_2(Gmats,Nsites)
  integer                                                                :: Nsites
  complex(8),dimension(Nsites,Nspin*Norb,Nspin*Norb,Lmats),intent(inout) :: Gmats
  integer                                                                :: io,jo,iorb,jorb,ispin,jspin,ilat
  do ilat=1,Nsites
     do ispin=1,Nspin
        do jspin=1,Nspin
           do iorb=1,Norb
              do jorb=1,Norb
                 io = iorb + (ispin-1)*Norb
                 jo = jorb + (jspin-1)*Norb
                 Gmats(ilat,io,jo,:) = G0matsii(ilat,ispin,jspin,iorb,jorb,:)
              enddo
           enddo
        enddo
     enddo
  enddo
end subroutine ed_get_g0imp_matsubara_lattice_2

subroutine ed_get_g0imp_matsubara_lattice_3(Gmats,Nsites,ispin,jspin,iorb,jorb)
  integer                                          :: Nsites
  complex(8),dimension(Nsites,Lmats),intent(inout) :: Gmats
  integer                                          :: iorb,jorb,ispin,jspin
  Gmats(1:Nsites,:) = G0matsii(1:Nsites,ispin,jspin,iorb,jorb,:)
end subroutine ed_get_g0imp_matsubara_lattice_3






subroutine ed_get_g0imp_matsubara_lattice_11(Gmats,ilat)
  integer                                                         :: ilat
  complex(8),dimension(Nspin,Nspin,Norb,Norb,Lmats),intent(inout) :: Gmats
  Gmats(:,:,:,:,:) = G0matsii(ilat,:,:,:,:,:)
end subroutine ed_get_g0imp_matsubara_lattice_11

subroutine ed_get_g0imp_matsubara_lattice_21(Gmats,ilat)
  integer                                                         :: ilat
  complex(8),dimension(Nspin*Norb,Nspin*Norb,Lmats),intent(inout) :: Gmats
  integer                                                         :: io,jo,iorb,jorb,ispin,jspin
  do ispin=1,Nspin
     do jspin=1,Nspin
        do iorb=1,Norb
           do jorb=1,Norb
              io = iorb + (ispin-1)*Norb
              jo = jorb + (jspin-1)*Norb
              Gmats(io,jo,:) = G0matsii(ilat,ispin,jspin,iorb,jorb,:)
           enddo
        enddo
     enddo
  enddo
end subroutine ed_get_g0imp_matsubara_lattice_21

subroutine ed_get_g0imp_matsubara_lattice_31(Gmats,ilat,ispin,jspin,iorb,jorb)
  integer                                   :: ilat
  complex(8),dimension(Lmats),intent(inout) :: Gmats
  integer                                   :: iorb,jorb,ispin,jspin
  Gmats(:) = G0matsii(ilat,ispin,jspin,iorb,jorb,:)
end subroutine ed_get_g0imp_matsubara_lattice_31
