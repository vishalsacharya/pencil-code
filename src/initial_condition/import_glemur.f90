!  Initial condition (density, magnetic field, velocity) 
!  for a field from the code GLEMuR.
!
!  04-sep-14/simon
!
!** AUTOMATIC CPARAM.INC GENERATION ****************************
! Declare (for generation of cparam.inc) the number of f array
! variables and auxiliary variables added by this module
!
! CPARAM logical, parameter :: linitial_condition = .true.
!
!***************************************************************
module InitialCondition
!
  use Cparam
  use Cdata
  use General, only: keep_compiler_quiet
  use Messages
!
  implicit none
!
  include '../initial_condition.h'
!
! ampl = amplitude of the magnetic field
! width_ring = width of the flux tube
! C = offset from the center of the knot, should be > 1
! D = extention coefficient for the z direction
! phase = relative phase of the z-variation
! [xyz]scale = scale in each dimension
! [xyz]shift = shift in each dimension in a 2*pi box

  character (len=labellen) :: vtkFile='gm2pc.vtk'
!
  namelist /initial_condition_pars/ &
      vtkFile
!
  contains
!***********************************************************************
    subroutine register_initial_condition()
!
!  Configure pre-initialised (i.e. before parameter read) variables
!  which should be know to be able to evaluate
!
!  07-oct-09/wlad: coded
!
!  Identify CVS/SVN version information.
!
      if (lroot) call svn_id( &
           "$Id: iucaa_logo.f90 19193 2012-06-30 12:55:46Z wdobler $")
!
    endsubroutine register_initial_condition
!***********************************************************************
    subroutine initial_condition_uu(f)
!
!  Initialize the velocity field.
!
!  07-may-09/wlad: coded
!
      real, dimension (mx,my,mz,mfarray), intent(inout) :: f
!
      call keep_compiler_quiet(f)
!
    endsubroutine initial_condition_uu
!***********************************************************************
    subroutine initial_condition_lnrho(f)
!
!  Initialize logarithmic density. init_lnrho 
!  will take care of converting it to linear 
!  density if you use ldensity_nolog
!
!  07-may-09/wlad: coded
!
      real, dimension (mx,my,mz,mfarray), intent(inout) :: f
!
      call keep_compiler_quiet(f)
!
    endsubroutine initial_condition_lnrho
!***********************************************************************
    subroutine initial_condition_aa(f)
!
!  Initialize the magnetic vector potential.
!
!  04-sep-14/simon: coded
!
!  Load the magnetic field from a vtk file created by GLEMuR
!  and compute the magnetic vector potential from it.
!
!  Created 2014-09-04 by Simon Candelaresi (Iomsn)
!
      use Mpicomm, only: stop_it
      use Poisson
      use Sub
      
      real, dimension (mx,my,mz,mfarray) :: f
      integer :: fileSize
      character(len = :), allocatable :: raw  ! contains the unformatted data
      real*4, allocatable :: bb(:,:,:,:)      ! magnetic field
      real*8, allocatable :: bb64(:,:,:,:)    ! for double precision
      integer :: vtkX, vtkY, vtkZ, nPoints
      integer :: p64
      integer :: pos, l, j, ju
      ! The next 2 variables are used for the uncurling.
      real, dimension (nx,ny,nz,3) :: jj, tmpJ  ! This is phi for poisson.f90
!      
!  Read the vtk file (B and x)
!
! check the length of the file and allocate array for the raw unformatted data
      inquire(file = vtkFile, size = fileSize)
      write(*,*) 'file size = ', fileSize, '  bytes'
      allocate(character(len = fileSize) :: raw)
!
! open the binary file
      open(0, file = vtkFile, form = 'unformatted', action = 'read', convert = 'big_endian', access = 'stream')
!
! read the raw data
      read(0) raw
!
! extract the parameters and data
      pos = index(raw, 'DIMENSIONS')
      read(raw(pos+10:pos+10+10), '(i10)') vtkX
      read(raw(pos+20:pos+20+10), '(i10)') vtkY
      read(raw(pos+30:pos+30+10), '(i10)') vtkZ
      write(*,*) "nxyz = ", vtkX, vtkY, vtkZ
      nPoints = vtkX*vtkY*vtkZ
      write(*,*) 'nPoints = ', nPoints
!
! allocate array
      allocate(bb(3,vtkX,vtkY,vtkZ))
!
! determine if single or double precision
      pos = index(raw, "VECTORS bfield")
      if (index(raw(pos+1:pos+7), 'double') > 0) then
        write(*,*) 'double = true'
        p64 = 1
        allocate(bb64(3,vtkX,vtkY,vtkZ))
      else
        write(*,*) 'float = true'
        p64 = 0
      endif
!
! read the magnetic field
      f(:,:,:,iaz) = 1
      pos = index(raw, "VECTORS bfield") + 21 + p64
      do n = 1, vtkZ
        do m = 1, vtkY
          do l = 1, vtkX
            if (p64 == 0) then
              read(0, rec = pos+4*(0 + (n-1)*3 + (m-1)*vtkZ*3 + (l-1)*vtkZ*vtkY*3)) bb(1,l,m,n)
              read(0, rec = pos+4*(1 + (n-1)*3 + (m-1)*vtkZ*3 + (l-1)*vtkZ*vtkY*3)) bb(2,l,m,n)
              read(0, rec = pos+4*(2 + (n-1)*3 + (m-1)*vtkZ*3 + (l-1)*vtkZ*vtkY*3)) bb(3,l,m,n)
            else
              read(0, rec = pos+8*(0 + (n-1)*3 + (m-1)*vtkZ*3 + (l-1)*vtkZ*vtkY*3)) bb64(1,l,m,n)
              read(0, rec = pos+8*(1 + (n-1)*3 + (m-1)*vtkZ*3 + (l-1)*vtkZ*vtkY*3)) bb64(2,l,m,n)
              read(0, rec = pos+8*(2 + (n-1)*3 + (m-1)*vtkZ*3 + (l-1)*vtkZ*vtkY*3)) bb64(3,l,m,n)
              bb(1,l,m,n) = real(bb64(1,l,m,n))
              bb(2,l,m,n) = real(bb64(2,l,m,n))
              bb(3,l,m,n) = real(bb64(3,l,m,n))
            endif
            f(l+nghost,m+nghost,n+nghost,iax:iaz) = bb(:,l,m,n)
!             write(*,*) f(l,m,n,iax:iaz)
          enddo
        enddo
      enddo
!
      deallocate(bb)
      deallocate(raw)
      close(0)

!  Transform the magnetic field into a vector potential

!  Compute curl(B) = J for the Poisson solver
      do m=m1,m2
         do n=n1,n2
            call curl(f,iaa,jj(:,m-nghost,n-nghost,:))
         enddo
      enddo
      tmpJ = -jj
!  Use the Poisson solver to solve \nabla^2 A = -J for A
      do j=1,3
        call inverse_laplacian(f,tmpJ(:,:,:,j))
      enddo
!
!  Overwrite the f-array with the correct vector potential A
      do j=1,3
          ju=iaa-1+j
          f(l1:l2,m1:m2,n1:n2,ju) = tmpJ(:,:,:,j)
      enddo
!      
!
    endsubroutine initial_condition_aa
!***********************************************************************
    subroutine read_initial_condition_pars(unit,iostat)
!
!  07-may-09/wlad: coded
!
      integer, intent(in) :: unit
      integer, intent(inout), optional :: iostat
!
      if (present(iostat)) then
        read(unit,NML=initial_condition_pars,ERR=99, IOSTAT=iostat)
      else
        read(unit,NML=initial_condition_pars,ERR=99)
      endif
      print*, 'nfoil: read initial conditions'
!
99    return
!
    endsubroutine read_initial_condition_pars
!***********************************************************************
    subroutine write_initial_condition_pars(unit)
!     
      integer, intent(in) :: unit
!
      write(unit,NML=initial_condition_pars)
!
    endsubroutine write_initial_condition_pars
!********************************************************************
!************        DO NOT DELETE THE FOLLOWING       **************
!********************************************************************
!**  This is an automatically generated include file that creates  **
!**  copies dummy routines from noinitial_condition.f90 for any    **
!**  InitialCondition routines not implemented in this file        **
!**                                                                **
    include '../initial_condition_dummies.inc'
!********************************************************************
  endmodule InitialCondition