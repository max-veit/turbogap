! HND XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX
! HND X
! HND X   TurboGAP
! HND X
! HND X   TurboGAP is copyright (c) 2019-2023, Miguel A. Caro and others
! HND X
! HND X   TurboGAP is published and distributed under the
! HND X      Academic Software License v1.0 (ASL)
! HND X
! HND X   This file, mc.f90, is copyright (c) 2019-2023, Miguel A. Caro
! HND X
! HND X   This file was authored by Tigany Zarrouk
! HND X
! HND X   TurboGAP is distributed in the hope that it will be useful for non-commercial
! HND X   academic research, but WITHOUT ANY WARRANTY; without even the implied
! HND X   warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
! HND X   ASL for more details.
! HND X
! HND X   You should have received a copy of the ASL along with this program
! HND X   (e.g. in a LICENSE.md file); if not, you can write to the original
! HND X   licensor, Miguel Caro (mcaroba@gmail.com). The ASL is also published at
! HND X   http://github.com/gabor1/ASL
! HND X
! HND X   When using this software, please cite the following reference:
! HND X
! HND X   Miguel A. Caro. Phys. Rev. B 100, 024112 (2019)
! HND X
! HND XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX

module mc

  use neighbors
  use md
  use types

  contains

!   These are the routines for calculating the monte-carlo acceptance criteria for different move types
  subroutine monte_carlo_insertion(p_accept, e_new, e_prev, temp, mu, m, volume, volume_bias, N_exch)
    implicit none

    real*8, intent(in) :: e_new, e_prev, temp, mu, m, volume, volume_bias
    integer, intent(in) :: N_exch
    real*8 :: lam
    real*8 :: kB = 8.617333262e-5, hbar = 6.582119569e-1, pi=3.1415926535
    real*8, intent(out) :: p_accept
    ! mass has units eV*fs^2/A^2
    ! hbar in eV.fs
    ! lam is thermal debroglie wavelength
    lam = sqrt( ( 2.0 * pi * hbar*hbar ) / ( m * kB * temp ) )

    p_accept =  (volume*volume_bias) / (lam**3.0 * (N_exch + 1)) * &
                exp( -( e_new - e_prev - mu  ) / (kB * temp) )

  end subroutine monte_carlo_insertion


  subroutine monte_carlo_removal(p_accept, e_new, e_prev, temp, mu, m, volume, volume_bias, N_exch)
    implicit none

    real*8, intent(in) :: e_new, e_prev, temp, mu, m, volume, volume_bias
    integer, intent(in) :: N_exch
    real*8 :: lam
    real*8 :: kB = 8.617333262e-5, hbar = 6.582119569e-1, pi=3.1415926535
    real*8, intent(out) :: p_accept
    ! mass has units eV*fs^2/A^2
    ! hbar in eV.fs
    ! lam is thermal debroglie wavelength
    lam = sqrt( ( 2.0 * pi * hbar*hbar ) / ( m * kB * temp ) )

    p_accept = (lam**3.0 * N_exch ) / (volume*volume_bias)  * &
                exp( -( e_new - e_prev + mu  ) / (kB * temp) )

  end subroutine monte_carlo_removal

  subroutine monte_carlo_move(p_accept, e_new, e_prev, temp)
    implicit none

    real*8, intent(in) :: e_new, e_prev, temp
    real*8 :: kB = 8.617333262e-5
    real*8, intent(out) :: p_accept
    p_accept = exp( -( e_new - e_prev ) / (kB * temp) )

  end subroutine monte_carlo_move

  subroutine monte_carlo_volume(p_accept, e_new, e_prev, temp, V_new, V_prev, P, N_exch)
    implicit none

    real*8, intent(in) :: e_new, e_prev, temp, V_new, V_prev, P
    real*8 :: kB = 8.617333262e-5, beta
    integer, intent(in) :: N_exch
    real*8, intent(out) :: p_accept

    beta = (1./(kB * temp))
    p_accept = exp( - beta * ( (e_new - e_prev) + &
                      P * ( V_new-V_prev ) + &
                     -(N_exch+1) * log( V_new/V_prev )/ beta ) )
  end subroutine monte_carlo_volume

  ! Not implemented this yet as it is a little complicated as one has
  ! to recalculate the neighbours but with the mc_min_dist as the
  ! cutoff!

  ! subroutine get_volume_bias(volume_bias, mc_min_dist, positions, &
  !      n_neigh, neighbor_list, n_atom_pairs)
  !   implicit none

  !   real*8, intent(in) :: mc_min_dist, positions(:,:)
  !   real*8, intent(out) :: volume_bias
  !   integer :: n_neigh(:), neighbor_list(:), n_atom_pairs

  !   ! is the number of neighbors for a given atom index including itself


  ! end subroutine get_volume_bias



    

  subroutine get_mc_acceptance(mc_move, p_accept, energy, energy_prev, temp, &
       mu, n_mc_species, v_uc, v_uc_prev, mass, pressure)
    implicit none

    character*32, intent(in) :: mc_move
    real*8, intent(out) :: p_accept
    real*8, intent(in) ::  energy, energy_prev, temp, &
         mu, v_uc, v_uc_prev, mass, pressure
    integer, intent(in) :: n_mc_species



    if (mc_move == "move" .or. mc_move == "relax" .or. mc_move == "md")then
       call monte_carlo_move(p_accept, energy, energy_prev, temp)
       !     Not implemented the volume bias yet
    else if (mc_move == "insertion")then
       call monte_carlo_insertion(p_accept, energy, energy_prev, temp, mu, &
            mass, v_uc, 1.0d0, n_mc_species)
    else if (mc_move == "removal")then
       call monte_carlo_removal(p_accept, energy, energy_prev, temp, mu, &
            mass, v_uc, 1.0d0, n_mc_species)
    else if (mc_move == "volume")then
       call monte_carlo_volume(p_accept, energy, energy_prev, temp, &
            v_uc, v_uc_prev, pressure, n_mc_species)
    end if

  end subroutine get_mc_acceptance

  subroutine mc_get_atom_disp(n_sites, move_max, idx, disp, d_disp)
    implicit none


    real*8, intent(out) :: disp(1:3), d_disp
    integer, intent(out) :: idx
    real*8, intent(in) :: move_max
    integer, intent(in) :: n_sites
    real*8 :: ranf, ranv(1:3)

!          Choose a random atom and displace it
    call random_number(ranf)
    idx = floor( ranf * n_sites ) + 1
    call random_number(ranv)
!          displacement
    disp = move_max * ( ranv - 0.5d0 )
    d_disp = norm2(disp)
!          Now pick a random index and displace

  end subroutine mc_get_atom_disp


  subroutine get_mc_move(n_mc_species, mc_types, mc_move, acceptance)
    implicit none

    integer, intent(in) :: n_mc_species
    integer :: n_mc, i
    character*32, intent(in) ::  mc_types(:)
    character*32, intent(out) :: mc_move
    real*8 :: ranf, acceptance(:), k
    logical :: invalid_move, cant_remove

    invalid_move = .true.
    do while( invalid_move )
       call random_number(ranf)

       ! Now choose the move based on the acceptance ratios

       k = 0.d0
       do i = 1, size(mc_types)
          n_mc = i
          k = k + acceptance(i)
          if( ranf < k )then
             print *, "k ", k, "n_mc ", i
             exit
          end if
       end do
       ! Original implementation n_mc = floor( size( mc_types,1 ) * ranf ) + 1
       print *, "n_mc = ", n_mc
       mc_move = mc_types(n_mc)

! If there are none of the gc species to remove, then we can't remove!!
       cant_remove =  (n_mc_species == 0 .and. mc_move == "removal" )

       if(cant_remove)then
          invalid_move = .true.
       else
          invalid_move = .false.
       end if
    end do

  end subroutine get_mc_move


  subroutine mc_insert_site(mc_species, positions, ref_positions, idx, n_sites, a_box, b_box, c_box, &
       indices, species, ref_species, xyz_species, ref_xyz_species, min_dist )

    implicit none

    real*8, intent(inout) :: positions(:,:)
    real*8, intent(out) :: ref_positions(:,:)
    real*8, intent(in) :: a_box(1:3), b_box(1:3), c_box(1:3), min_dist
    real*8 :: ranv(1:3)
    integer, intent(in) :: idx, n_sites, indices(1:3), ref_species(:)
    integer, intent(inout) :: species(:)
    character*8, intent(in) :: ref_xyz_species(:)
    character*8, intent(inout) :: xyz_species(:)
    character*32, intent(in) :: mc_species
    logical :: too_close

    positions(1:3,1:n_sites-1) = ref_positions(1:3,1:n_sites-1)
    positions(1:3,1:n_sites-1) = ref_positions(1:3,1:n_sites-1)
    xyz_species(1:n_sites-1)= ref_xyz_species(1:n_sites-1)
    species(1:n_sites-1)= ref_species(1:n_sites-1)

    xyz_species(n_sites) = mc_species

    too_close = .true.
    do while ( too_close )

       call random_number(ranv)
       positions(1,n_sites) = ranv(1)*norm2(a_box)
       positions(2,n_sites) = ranv(2)*norm2(b_box)
       positions(3,n_sites) = ranv(3)*norm2(c_box)

       call wrap_pbc(positions(1:3,1:n_sites), a_box/dfloat(indices(1)), &
            b_box/dfloat(indices(2)), c_box/dfloat(indices(3)))

       call check_if_atoms_too_close(positions(1:3,n_sites), ref_positions, n_sites-1, &
            a_box, b_box, c_box, min_dist, too_close)

    end do

  end subroutine mc_insert_site


  subroutine check_if_atoms_too_close(position, ref_positions, n_sites, &
       a_box, b_box, c_box, min_dist, too_close)
    implicit none
    integer, intent(in) :: n_sites
    integer :: i, i_shift(1:3)
    real*8, intent(in) :: position(:), ref_positions(:,:), min_dist
    real*8, intent(in) :: a_box(1:3), b_box(1:3), c_box(1:3)
    real*8 :: d, dist(1:3)
    logical, intent(inout) :: too_close

    too_close = .false.
    do i = 1, n_sites
       call get_distance(position(1:3), ref_positions(1:3,i), &
            a_box, b_box, c_box, (/ .true., .true., .true. /), dist, d, i_shift)

       if( d < min_dist )then
          too_close=.true.
          exit
       end if
    end do

  end subroutine check_if_atoms_too_close


  subroutine perform_mc_step(&
       & positions, species, xyz_species, masses, fix_atom,&
       & velocities, positions_prev, positions_diff, disp, d_disp,&
       & mc_acceptance, hirshfeld_v, hirshfeld_v_temp, energies,&
       & forces, forces_prev, n_sites, n_mc_species, mc_move, mc_species,&
       & mc_move_max, mc_min_dist, mc_types, masses_types,&
       & species_idx, im_pos, im_species, im_xyz_species, im_fix_atom&
       &, im_masses, a_box, b_box, c_box, indices, do_md, mc_relax,&
       & md_istep, mc_id)

    implicit none

    real*8, allocatable, intent(inout) :: positions(:,:), masses(:), hirshfeld_v(:),&
         forces_prev(:,:), positions_prev(:,:), positions_diff(:,:),&
         mc_acceptance(:), hirshfeld_v_temp(:), velocities(:,:), &
         energies(:), forces(:,:), masses_types(:), im_pos(:,:), im_masses(:)
    real*8 :: mc_move_max, ranf, ranv(1:3)
    real*8, intent(inout) :: disp(1:3), mc_min_dist, d_disp

    integer, intent(inout) :: n_mc_species, n_sites, md_istep, mc_id
    integer, allocatable, intent(inout) :: species(:), im_species(:)
    character*8, allocatable :: species_types(:), xyz_species(:), xyz_species_supercell(:),&
         im_xyz_species(:)
    character*32, intent(inout) :: mc_move, mc_species
    character*32, allocatable, intent(in) ::  mc_types(:)
    integer :: idx, i
    integer, allocatable, intent(inout) :: species_idx(:)
    type(image), allocatable :: images
    integer :: indices(1:3)
    real*8 :: a_box(1:3), b_box(1:3), c_box(1:3)
    logical, allocatable:: fix_atom(:,:), im_fix_atom(:,:)
    logical, intent(inout) :: do_md, mc_relax

    n_sites = size(positions, 2)
    ! Count the mc species (no multi species mc just yet)
    n_mc_species = 0
    do i = 1, n_sites
       if (xyz_species(i) == mc_species)then
          n_mc_species = n_mc_species + 1
       end if
    end do

    !  Get the mc move type using a random number
    call get_mc_move(n_mc_species, mc_types, mc_move, mc_acceptance)

    write(*,'(1X,A,1X,A)') " Next MC Move: ", mc_move

    if (mc_move == "move")then
       call mc_get_atom_disp(n_sites, mc_move_max, idx, disp, d_disp)
       write(*,'(A,1X,I8,1X,A,F22.8,1X,A)')'    MC Move: atom ', idx, ' distance = ', d_disp, 'A '
       positions(1:3, idx) = positions(1:3, idx) + disp
    end if

    if (mc_move == "relax" .or. mc_move == "md" .or. mc_relax)then
       md_istep = -1
       do_md = .true.
       if(allocated(forces_prev))deallocate(forces_prev)
       allocate( forces_prev(1:3, 1:n_sites) )
       if(allocated(positions_diff))deallocate(positions_diff)
       allocate( positions_diff(1:3, 1:n_sites) )
       if(allocated(positions_prev))deallocate(positions_prev)
       allocate( positions_prev(1:3, 1:n_sites) )

       positions_diff = 0.d0

       ! Assume that the number of steps has already been set.
    end if

    if (mc_move == "insertion" .or. mc_move == "removal" )then

       !   Allocate temporary storage arrays
       if(allocated(hirshfeld_v))then
          if (.not. allocated(hirshfeld_v_temp))allocate(hirshfeld_v_temp(1:size(hirshfeld_v,1)))
          hirshfeld_v_temp(1:size(hirshfeld_v,1)) = hirshfeld_v(1:size(hirshfeld_v,1))
       end if

       if( allocated(species_idx))deallocate(species_idx)
       allocate( species_idx(1:n_mc_species) )

       n_mc_species = 0
       do i = 1, n_sites
          if (xyz_species(i) == mc_species)then
             n_mc_species = n_mc_species + 1
             species_idx(n_mc_species) = i
          end if
       end do


       if (mc_move == "insertion")then
          n_sites = n_sites + 1
       else if (mc_move == "removal")then
          n_sites = n_sites - 1
          call  random_number(ranf)
          ! Index of atom to remove
          idx = species_idx( floor( ranf * n_mc_species ) + 1 )
       end if

       if( allocated(energies) )deallocate( energies, positions, velocities, &
            forces, species,  &
            xyz_species, fix_atom)
       allocate( energies(1:n_sites) )
       allocate( forces(1:3, 1:n_sites) )
       allocate( velocities(1:3, 1:n_sites) )
       allocate( positions(1:3, 1:n_sites) )
       allocate( fix_atom(1:3, 1:n_sites) )
       allocate( xyz_species(1:n_sites) )
       allocate( species(1:n_sites) )
       velocities = 0.0d0
       forces = 0.0d0
       energies= 0.0d0

       if (mc_move == "insertion")then
          call mc_insert_site(mc_species, positions,&
               & im_pos, idx, n_sites,&
               & a_box, b_box, c_box, indices, species,&
               & im_species, xyz_species,&
               & im_xyz_species, mc_min_dist )

          deallocate(masses)
          allocate(masses(1:n_sites))
          masses(1:n_sites-1) = im_masses(1:n_sites-1)
          masses(n_sites) = masses_types(mc_id)

          if (allocated(hirshfeld_v))then
             deallocate(hirshfeld_v)
             allocate(hirshfeld_v(1:n_sites))
             hirshfeld_v(1:n_sites-1) = hirshfeld_v_temp(1:n_sites-1)
             ! ignoring the hirshfeld v just want to get rough implementation done
             hirshfeld_v(n_sites) = hirshfeld_v(n_sites-1)
          end if

       else if (mc_move == "removal")then
          deallocate(masses)
          allocate(masses(1:n_sites))

          if (allocated(hirshfeld_v))then
             deallocate(hirshfeld_v)
             allocate(hirshfeld_v(1:n_sites))
          end if

          do i = 1, n_sites
             if (i < idx)then
                positions(1:3,i) = im_pos(1:3,i)

                xyz_species(i)           = im_xyz_species(i)
                species(i)               = im_species(i)
                masses(i)= im_masses(i)
                fix_atom(1:3,i)= im_fix_atom(1:3,i)

                if (allocated(hirshfeld_v))hirshfeld_v(i) = hirshfeld_v_temp(i)
             else
                positions(1:3,i) = im_pos(1:3,i+1)
                xyz_species(i)           = im_xyz_species(i+1)
                species(i)               = im_species(i+1)
                masses(i)= im_masses(i+1)
                fix_atom(1:3,i)= im_fix_atom(1:3,i+1)
                if (allocated(hirshfeld_v))hirshfeld_v(i) = hirshfeld_v_temp(i+1)
             end if
          end do
       end if
    end if

    if( allocated(positions_prev) )deallocate( positions_prev )
    allocate( positions_prev(1:3, 1:n_sites) )
    if(allocated(forces_prev))deallocate(forces_prev)
    allocate( forces_prev(1:3, 1:n_sites) )
    if(allocated(positions_diff))deallocate(positions_diff)
    allocate( positions_diff(1:3, 1:n_sites) )
    positions_diff = 0.d0

  end subroutine perform_mc_step

  ! Implement this to make condition checking more clear
  ! subroutine get_mc_conditions()
  ! end subroutine get_mc_conditions


end module mc
