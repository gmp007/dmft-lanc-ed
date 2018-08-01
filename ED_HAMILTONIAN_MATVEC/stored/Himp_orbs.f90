  do i=1,Dim
     call state2indices(i,[DimUps,DimDws],Indices)
     do iorb=1,Norb
        Mups(iorb) = Hs(iorb)%map(Indices(iorb))
        Mdws(iorb) = Hs(Norb+iorb)%map(Indices(Norb+iorb))
        !
        Nups(iorb,:) = Bdecomp(Mups(iorb),Ns_Orb)
        Ndws(iorb,:) = Bdecomp(Mdws(iorb),Ns_Orb)
        !
        Nup(iorb) = Nups(iorb,1)
        Ndw(iorb) = Ndws(iorb,1)
     enddo
     !
     !
     !Diagonal Elements, i.e. local part
     htmp = zero
     do iorb=1,Norb
        htmp = htmp + impHloc(1,1,iorb,iorb)*Nup(iorb)
        htmp = htmp + impHloc(Nspin,Nspin,iorb,iorb)*Ndw(iorb)
        htmp = htmp - xmu*(Nup(iorb)+Ndw(iorb))
     enddo
     !
     call sp_insert_element(spH0d,htmp,i,i)
     !
  enddo


