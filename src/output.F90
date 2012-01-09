module output

  use ISO_FORTRAN_ENV

  use ace_header,      only: Nuclide, Reaction, UrrData
  use constants
  use datatypes,       only: dict_get_key
  use endf,            only: reaction_name
  use geometry_header, only: Cell, Universe, Surface
  use global
  use mesh_header,     only: StructuredMesh
  use particle_header, only: Particle, LocalCoord
  use string,          only: upper_case, to_str
  use tally_header,    only: TallyObject

  implicit none

  ! Short names for output and error units
  integer :: ou = OUTPUT_UNIT
  integer :: eu = ERROR_UNIT

contains

!===============================================================================
! TITLE prints the main title banner as well as information about the program
! developers, version, and date/time which the problem was run.
!===============================================================================

  subroutine title()

    character(10) :: today_date
    character(8)  :: today_time

    write(UNIT=OUTPUT_UNIT, FMT='(/11(A/))') &
         '       .d88888b.                             888b     d888  .d8888b.', &
         '      d88P" "Y88b                            8888b   d8888 d88P  Y88b', &
         '      888     888                            88888b.d88888 888    888', &
         '      888     888 88888b.   .d88b.  88888b.  888Y88888P888 888       ', &
         '      888     888 888 "88b d8P  Y8b 888 "88b 888 Y888P 888 888       ', &
         '      888     888 888  888 88888888 888  888 888  Y8P  888 888    888', &
         '      Y88b. .d88P 888 d88P Y8b.     888  888 888   "   888 Y88b  d88P', &
         '       "Y88888P"  88888P"   "Y8888  888  888 888       888  "Y8888P"', &
         '__________________888______________________________________________________', &
         '                  888', &
         '                  888'

    ! Write version information
    write(UNIT=OUTPUT_UNIT, FMT=*) &
         '     Developed At:  Massachusetts Institute of Technology'
    write(UNIT=OUTPUT_UNIT, FMT='(6X,"Version:",7X,I1,".",I1,".",I1)') &
         VERSION_MAJOR, VERSION_MINOR, VERSION_RELEASE

    ! Write the date and time
    call get_today(today_date, today_time)
    write(UNIT=OUTPUT_UNIT, FMT='(6X,"Date/Time:",5X,A,1X,A)') &
         trim(today_date), trim(today_time)

    ! Write information to summary file
    call header("OpenMC Monte Carlo Code", unit=UNIT_SUMMARY, level=1)
    write(UNIT=UNIT_SUMMARY, FMT=*) &
         "Copyright:     2011 Massachusetts Institute of Technology"
    write(UNIT=UNIT_SUMMARY, FMT='(1X,A,7X,2(I1,"."),I1)') &
         "Version:", VERSION_MAJOR, VERSION_MINOR, VERSION_RELEASE
    write(UNIT=UNIT_SUMMARY, FMT='(1X,"Date/Time:",5X,A,1X,A)') &
         trim(today_date), trim(today_time)

    ! Write information on number of processors
#ifdef MPI
    write(UNIT=OUTPUT_UNIT, FMT='(1X,A)') '     MPI Processes: ' // &
         trim(to_str(n_procs))
    write(UNIT=UNIT_SUMMARY, FMT='(1X,"MPI Processes:",1X,A)') &
         trim(to_str(n_procs))
#endif

  end subroutine title

!===============================================================================
! HEADER displays a header block according to a specified level. If no level is
! specified, it is assumed to be a minor header block (H3).
!===============================================================================

  subroutine header(msg, unit, level)

    character(*), intent(in) :: msg
    integer, optional :: unit
    integer, optional :: level

    integer :: n
    integer :: m
    integer :: unit_
    integer :: header_level
    character(MAX_LINE_LEN) :: line

    ! set default level
    if (present(level)) then
       header_level = level
    else
       header_level = 3
    end if

    ! set default unit
    if (present(unit)) then
       unit_ = unit
    else
       unit_ = OUTPUT_UNIT
    end if

    ! determine how many times to repeat '=' character
    n = (63 - len_trim(msg))/2
    m = n
    if (mod(len_trim(msg),2) == 0) m = m + 1

    ! convert line to upper case
    line = msg
    call upper_case(line)

    ! print header based on level
    select case (header_level)
    case (1)
       write(UNIT=unit_, FMT='(/3(1X,A/))') repeat('=', 75), & 
            repeat('=', n) // '>     ' // trim(line) // '     <' // &
            repeat('=', m), repeat('=', 75)
    case (2)
       write(UNIT=unit_, FMT='(/2(1X,A/))') trim(line), repeat('-', 75)
    case (3)
       write(UNIT=unit_, FMT='(/1X,A/)') repeat('=', n) // '>     ' // &
            trim(line) // '     <' // repeat('=', m)
    end select

  end subroutine header

!===============================================================================
! WRITE_MESSAGE displays an informational message to the log file and the 
! standard output stream.
!===============================================================================

  subroutine write_message(level)

    integer, optional :: level

    integer :: n_lines
    integer :: i

    ! Only allow master to print to screen
    if (.not. master .and. present(level)) return

    if (.not. present(level) .or. level <= verbosity) then
       n_lines = (len_trim(message)-1)/79 + 1
       do i = 1, n_lines
          write(ou, fmt='(1X,A)') trim(message(79*(i-1)+1:79*i))
       end do
    end if

  end subroutine write_message

!===============================================================================
! GET_TODAY determines the date and time at which the program began execution
! and returns it in a readable format
!===============================================================================

  subroutine get_today(today_date, today_time)

    character(10), intent(out) :: today_date
    character(8),  intent(out) :: today_time

    integer       :: val(8)
    character(8)  :: date_
    character(10) :: time_
    character(5)  :: zone

    call date_and_time(date_, time_, zone, val)
    ! val(1) = year (YYYY)
    ! val(2) = month (MM)
    ! val(3) = day (DD)
    ! val(4) = timezone
    ! val(5) = hours (HH)
    ! val(6) = minutes (MM)
    ! val(7) = seconds (SS)
    ! val(8) = milliseconds

    if (val(2) < 10) then
       if (val(3) < 10) then
          today_date = date_(6:6) // "/" // date_(8:8) // "/" // date_(1:4)
       else
          today_date = date_(6:6) // "/" // date_(7:8) // "/" // date_(1:4)
       end if
    else
       if (val(3) < 10) then
          today_date = date_(5:6) // "/" // date_(8:8) // "/" // date_(1:4)
       else
          today_date = date_(5:6) // "/" // date_(7:8) // "/" // date_(1:4)
       end if
    end if
    today_time = time_(1:2) // ":" // time_(3:4) // ":" // time_(5:6)

  end subroutine get_today

!===============================================================================
! PRINT_PARTICLE displays the attributes of a particle
!===============================================================================

  subroutine print_particle(p)

    type(Particle),   pointer :: p

    integer                   :: i
    type(Cell),       pointer :: c => null()
    type(Surface),    pointer :: s => null()
    type(Universe),   pointer :: u => null()
    type(Lattice),    pointer :: l => null()
    type(LocalCoord), pointer :: coord => null()

    ! display type of particle
    select case (p % type)
    case (NEUTRON)
       write(ou,*) 'Neutron ' // to_str(p % id)
    case (PHOTON)
       write(ou,*) 'Photon ' // to_str(p % id)
    case (ELECTRON)
       write(ou,*) 'Electron ' // to_str(p % id)
    case default
       write(ou,*) 'Unknown Particle ' // to_str(p % id)
    end select

    ! loop through each level of universes
    coord => p % coord0
    i = 0
    do while(associated(coord))
       ! Print level
       write(ou,*) '  Level ' // trim(to_str(i))

       ! Print cell for this level
       if (coord % cell /= NONE) then
          c => cells(coord % cell)
          write(ou,*) '    Cell             = ' // trim(to_str(c % id))
       end if

       ! Print universe for this level
       if (coord % universe /= NONE) then
          u => universes(coord % universe)
          write(ou,*) '    Universe         = ' // trim(to_str(u % id))
       end if

       ! Print information on lattice
       if (coord % lattice /= NONE) then
          l => lattices(coord % lattice)
          write(ou,*) '    Lattice          = ' // trim(to_str(l % id))
          write(ou,*) '    Lattice position = (' // trim(to_str(&
               p % coord % lattice_x)) // ',' // trim(to_str(&
               p % coord % lattice_y)) // ')'
       end if

       ! Print local coordinates
       write(ou,'(1X,A,3ES11.4)') '    xyz = ', coord % xyz
       write(ou,'(1X,A,3ES11.4)') '    uvw = ', coord % uvw

       coord => coord % next
       i = i + 1
    end do

    ! Print surface
    if (p % surface /= NONE) then
       s => surfaces(p % surface)
       write(ou,*) '    Surface = ' // to_str(s % id)
    end if

    write(ou,*) '  Weight = ' // to_str(p % wgt)
    write(ou,*) '  Energy = ' // to_str(p % E)
    write(ou,*) '  IE = ' // to_str(p % IE)
    write(ou,*) '  Interpolation factor = ' // to_str(p % interp)
    write(ou,*)

  end subroutine print_particle

!===============================================================================
! PRINT_REACTION displays the attributes of a reaction
!===============================================================================

  subroutine print_reaction(rxn)

    type(Reaction), pointer :: rxn

    write(ou,*) 'Reaction ' // reaction_name(rxn % MT)
    write(ou,*) '    MT = ' // to_str(rxn % MT)
    write(ou,*) '    Q-value = ' // to_str(rxn % Q_value)
    write(ou,*) '    TY = ' // to_str(rxn % TY)
    write(ou,*) '    Starting index = ' // to_str(rxn % IE)
    if (rxn % has_energy_dist) then
       write(ou,*) '    Energy: Law ' // to_str(rxn % edist % law)
    end if
    write(ou,*)

  end subroutine print_reaction

!===============================================================================
! PRINT_CELL displays the attributes of a cell
!===============================================================================

  subroutine print_cell(c, unit)

    type(Cell), pointer :: c
    integer,   optional :: unit

    integer :: temp
    integer :: i
    integer :: unit_
    character(MAX_LINE_LEN) :: string
    type(Universe), pointer :: u => null()
    type(Lattice),  pointer :: l => null()
    type(Material), pointer :: m => null()

    if (present(unit)) then
       unit_ = unit
    else
       unit_ = OUTPUT_UNIT
    end if

    write(unit_,*) 'Cell ' // to_str(c % id)
    temp = dict_get_key(cell_dict, c % id)
    write(unit_,*) '    Array Index = ' // to_str(temp)
    u => universes(c % universe)
    write(unit_,*) '    Universe = ' // to_str(u % id)
    select case (c % type)
    case (CELL_NORMAL)
       write(unit_,*) '    Fill = NONE'
    case (CELL_FILL)
       u => universes(c % fill)
       write(unit_,*) '    Fill = Universe ' // to_str(u % id)
    case (CELL_LATTICE)
       l => lattices(c % fill)
       write(unit_,*) '    Fill = Lattice ' // to_str(l % id)
    end select
    if (c % material == 0) then
       write(unit_,*) '    Material = NONE'
    else
       m => materials(c % material)
       write(unit_,*) '    Material = ' // to_str(m % id)
    end if
    write(unit_,*) '    Parent Cell = ' // to_str(c % parent)
    string = ""
    do i = 1, c % n_surfaces
       select case (c % surfaces(i))
       case (OP_LEFT_PAREN)
          string = trim(string) // ' ('
       case (OP_RIGHT_PAREN)
          string = trim(string) // ' )'
       case (OP_UNION)
          string = trim(string) // ' :'
       case (OP_DIFFERENCE)
          string = trim(string) // ' !'
       case default
          string = trim(string) // ' ' // to_str(c % surfaces(i))
       end select
    end do
    write(unit_,*) '    Surface Specification:' // trim(string)
    write(unit_,*)

  end subroutine print_cell

!===============================================================================
! PRINT_UNIVERSE displays the attributes of a universe
!===============================================================================

  subroutine print_universe(univ, unit)

    type(Universe), pointer :: univ
    integer,       optional :: unit

    integer :: i
    integer :: unit_
    character(MAX_LINE_LEN) :: string
    type(Cell), pointer     :: c => null()

    if (present(unit)) then
       unit_ = unit
    else
       unit_ = OUTPUT_UNIT
    end if

    write(unit_,*) 'Universe ' // to_str(univ % id)
    write(unit_,*) '    Level = ' // to_str(univ % level)
    string = ""
    do i = 1, univ % n_cells
       c => cells(univ % cells(i))
       string = trim(string) // ' ' // to_str(c % id)
    end do
    write(unit_,*) '    Cells =' // trim(string)
    write(unit_,*)

  end subroutine print_universe

!===============================================================================
! PRINT_LATTICE displays the attributes of a lattice
!===============================================================================

  subroutine print_lattice(lat, unit)

    type(Lattice), pointer :: lat
    integer,      optional :: unit

    integer :: unit_

    if (present(unit)) then
       unit_ = unit
    else
       unit_ = OUTPUT_UNIT
    end if

    write(unit_,*) 'Lattice ' // to_str(lat % id)
    write(unit_,*) '    n_x = ' // to_str(lat % n_x)
    write(unit_,*) '    n_y = ' // to_str(lat % n_y)
    write(unit_,*) '    x0 = ' // to_str(lat % x0)
    write(unit_,*) '    y0 = ' // to_str(lat % y0)
    write(unit_,*) '    width_x = ' // to_str(lat % width_x)
    write(unit_,*) '    width_y = ' // to_str(lat % width_y)
    write(unit_,*)

  end subroutine print_lattice

!===============================================================================
! PRINT_SURFACE displays the attributes of a surface
!===============================================================================

  subroutine print_surface(surf, unit)

    type(Surface), pointer :: surf
    integer,      optional :: unit

    integer :: i
    integer :: unit_
    character(MAX_LINE_LEN) :: string

    if (present(unit)) then
       unit_ = unit
    else
       unit_ = OUTPUT_UNIT
    end if

    write(unit_,*) 'Surface ' // to_str(surf % id)
    select case (surf % type)
    case (SURF_PX)
       string = "X Plane"
    case (SURF_PY)
       string = "Y Plane"
    case (SURF_PZ)
       string = "Z Plane"
    case (SURF_PLANE)
       string = "Plane"
    case (SURF_CYL_X)
       string = "X Cylinder"
    case (SURF_CYL_Y)
       string = "Y Cylinder"
    case (SURF_CYL_Z)
       string = "Z Cylinder"
    case (SURF_SPHERE)
       string = "Sphere"
    case (SURF_BOX_X)
    case (SURF_BOX_Y)
    case (SURF_BOX_Z)
    case (SURF_BOX)
    case (SURF_GQ)
       string = "General Quadratic"
    end select
    write(unit_,*) '    Type = ' // trim(string)

    string = ""
    do i = 1, size(surf % coeffs)
       string = trim(string) // ' ' // to_str(surf % coeffs(i), 4)
    end do
    write(unit_,*) '    Coefficients = ' // trim(string)

    string = ""
    if (allocated(surf % neighbor_pos)) then
       do i = 1, size(surf % neighbor_pos)
          string = trim(string) // ' ' // to_str(surf % neighbor_pos(i))
       end do
    end if
    write(unit_,*) '    Positive Neighbors = ' // trim(string)

    string = ""
    if (allocated(surf % neighbor_neg)) then
       do i = 1, size(surf % neighbor_neg)
          string = trim(string) // ' ' // to_str(surf % neighbor_neg(i))
       end do
    end if
    write(unit_,*) '    Negative Neighbors =' // trim(string)
    select case (surf % bc)
    case (BC_TRANSMIT)
       write(unit_,*) '    Boundary Condition = Transmission'
    case (BC_VACUUM)
       write(unit_,*) '    Boundary Condition = Vacuum'
    case (BC_REFLECT)
       write(unit_,*) '    Boundary Condition = Reflective'
    case (BC_PERIODIC)
       write(unit_,*) '    Boundary Condition = Periodic'
    end select
    write(unit_,*)

  end subroutine print_surface

!===============================================================================
! PRINT_MATERIAL displays the attributes of a material
!===============================================================================

  subroutine print_material(mat, unit)

    type(Material), pointer :: mat
    integer,       optional :: unit

    integer :: i
    integer :: unit_
    real(8) :: density
    character(MAX_LINE_LEN) :: string
    type(Nuclide),  pointer :: nuc => null()

    if (present(unit)) then
       unit_ = unit
    else
       unit_ = OUTPUT_UNIT
    end if

    ! Write identifier for material
    write(unit_,*) 'Material ' // to_str(mat % id)

    ! Write total atom density in atom/b-cm
    write(unit_,*) '    Atom Density = ' // trim(to_str(mat % density)) &
         // ' atom/b-cm'

    ! Write atom density for each nuclide in material
    write(unit_,*) '    Nuclides:'
    do i = 1, mat % n_nuclides
       nuc => nuclides(mat % nuclide(i))
       density = mat % atom_density(i)
       string = '        ' // trim(nuc % name) // ' = ' // &
            trim(to_str(density)) // ' atom/b-cm'
       write(unit_,*) trim(string)
    end do

    ! Write information on S(a,b) table
    if (mat % has_sab_table) then
       write(unit_,*) '    S(a,b) table = ' // trim(mat % sab_name)
    end if
    write(unit_,*)

  end subroutine print_material

!===============================================================================
! PRINT_TALLY displays the attributes of a tally
!===============================================================================

  subroutine print_tally(t, unit)

    type(TallyObject), pointer :: t
    integer,          optional :: unit

    integer :: i
    integer :: id
    integer :: unit_
    character(MAX_LINE_LEN) :: string
    type(Cell),           pointer :: c => null()
    type(Surface),        pointer :: s => null()
    type(Universe),       pointer :: u => null()
    type(Material),       pointer :: m => null()
    type(StructuredMesh), pointer :: sm => null()

    if (present(unit)) then
       unit_ = unit
    else
       unit_ = OUTPUT_UNIT
    end if

    write(unit_,*) 'Tally ' // to_str(t % id)

    if (t % n_bins(T_CELL) > 0) then
       string = ""
       do i = 1, t % n_bins(T_CELL)
          id = t % cell_bins(i) % scalar
          c => cells(id)
          string = trim(string) // ' ' // trim(to_str(c % id))
       end do
       write(unit_, *) '    Cell Bins:' // trim(string)
    end if

    if (t % n_bins(T_SURFACE) > 0) then
       string = ""
       do i = 1, t % n_bins(T_SURFACE)
          id = t % surface_bins(i) % scalar
          s => surfaces(id)
          string = trim(string) // ' ' // trim(to_str(s % id))
       end do
       write(unit_, *) '    Surface Bins:' // trim(string)
    end if

    if (t % n_bins(T_UNIVERSE) > 0) then
       string = ""
       do i = 1, t % n_bins(T_UNIVERSE)
          id = t % universe_bins(i) % scalar
          u => universes(id)
          string = trim(string) // ' ' // trim(to_str(u % id))
       end do
       write(unit_, *) '    Material Bins:' // trim(string)
    end if

    if (t % n_bins(T_MATERIAL) > 0) then
       string = ""
       do i = 1, t % n_bins(T_MATERIAL)
          id = t % material_bins(i) % scalar
          m => materials(id)
          string = trim(string) // ' ' // trim(to_str(m % id))
       end do
       write(unit_, *) '    Material Bins:' // trim(string)
    end if

    if (t % n_bins(T_MESH) > 0) then
       string = ""
       id = t % mesh
       sm => meshes(id)
       string = trim(string) // ' ' // trim(to_str(sm % dimension(1)))
       do i = 2, sm % n_dimension
          string = trim(string) // ' x ' // trim(to_str(sm % dimension(i)))
       end do
       write(unit_, *) '    Mesh Bins:' // trim(string)
    end if

    if (t % n_bins(T_CELLBORN) > 0) then
       string = ""
       do i = 1, t % n_bins(T_CELLBORN)
          id = t % cellborn_bins(i) % scalar
          c => cells(id)
          string = trim(string) // ' ' // trim(to_str(c % id))
       end do
       write(unit_, *) '    Birth Region Bins:' // trim(string)
    end if

    if (t % n_bins(T_ENERGYIN) > 0) then
       string = ""
       do i = 1, t % n_bins(T_ENERGYIN) + 1
          string = trim(string) // ' ' // trim(to_str(&
               t % energy_in(i)))
       end do
       write(unit_,*) '    Incoming Energy Bins:' // trim(string)
    end if

    if (t % n_bins(T_ENERGYOUT) > 0) then
       string = ""
       do i = 1, t % n_bins(T_ENERGYOUT) + 1
          string = trim(string) // ' ' // trim(to_str(&
               t % energy_out(i)))
       end do
       write(unit_,*) '    Outgoing Energy Bins:' // trim(string)
    end if

    if (t % n_macro_bins > 0) then
       string = ""
       do i = 1, t % n_macro_bins
          select case (t % macro_bins(i) % scalar)
          case (MACRO_FLUX)
             string = trim(string) // ' flux'
          case (MACRO_TOTAL)
             string = trim(string) // ' total'
          case (MACRO_SCATTER)
             string = trim(string) // ' scatter'
          case (MACRO_ABSORPTION)
             string = trim(string) // ' absorption'
          case (MACRO_FISSION)
             string = trim(string) // ' fission'
          case (MACRO_NU_FISSION)
             string = trim(string) // ' nu-fission'
          end select
       end do
       write(unit_,*) '    Macro Reactions:' // trim(string)
    end if
    write(unit_,*)

  end subroutine print_tally

!===============================================================================
! PRINT_GEOMETRY displays the attributes of all cells, surfaces, universes,
! surfaces, and lattices read in the input files.
!===============================================================================

  subroutine print_geometry()

    integer :: i
    type(Surface),     pointer :: s => null()
    type(Cell),        pointer :: c => null()
    type(Universe),    pointer :: u => null()
    type(Lattice),     pointer :: l => null()

    ! print summary of surfaces
    call header("SURFACE SUMMARY", unit=UNIT_SUMMARY)
    do i = 1, n_surfaces
       s => surfaces(i)
       call print_surface(s, unit=UNIT_SUMMARY)
    end do

    ! print summary of cells
    call header("CELL SUMMARY", unit=UNIT_SUMMARY)
    do i = 1, n_cells
       c => cells(i)
       call print_cell(c, unit=UNIT_SUMMARY)
    end do

    ! print summary of universes
    call header("UNIVERSE SUMMARY", unit=UNIT_SUMMARY)
    do i = 1, n_universes
       u => universes(i)
       call print_universe(u, unit=UNIT_SUMMARY)
    end do

    ! print summary of lattices
    if (n_lattices > 0) then
       call header("LATTICE SUMMARY", unit=UNIT_SUMMARY)
       do i = 1, n_lattices
          l => lattices(i)
          call print_lattice(l, unit=UNIT_SUMMARY)
       end do
    end if

  end subroutine print_geometry

!===============================================================================
! PRINT_NUCLIDE displays information about a continuous-energy neutron
! cross_section table and its reactions and secondary angle/energy distributions
!===============================================================================

  subroutine print_nuclide(nuc, unit)

    type(Nuclide), pointer :: nuc
    integer,      optional :: unit

    integer :: i
    integer :: unit_
    integer :: size_total
    integer :: size_xs
    integer :: size_angle
    integer :: size_energy
    type(Reaction), pointer :: rxn => null()
    type(UrrData), pointer :: urr => null()

    ! set default unit for writing information
    if (present(unit)) then
       unit_ = unit
    else
       unit_ = OUTPUT_UNIT
    end if

    ! Determine size of cross-sections
    size_xs = (5 + nuc % n_reaction) * nuc % n_grid * 8
    size_total = size_xs

    ! Basic nuclide information
    write(unit_,*) 'Nuclide ' // trim(nuc % name)
    write(unit_,*) '  zaid = ' // trim(to_str(nuc % zaid))
    write(unit_,*) '  awr = ' // trim(to_str(nuc % awr))
    write(unit_,*) '  kT = ' // trim(to_str(nuc % kT))
    write(unit_,*) '  # of grid points = ' // trim(to_str(nuc % n_grid))
    write(unit_,*) '  Fissionable = ', nuc % fissionable
    write(unit_,*) '  # of fission reactions = ' // trim(to_str(nuc % n_fission))
    write(unit_,*) '  # of reactions = ' // trim(to_str(nuc % n_reaction))
    write(unit_,*) '  Size of cross sections = ' // trim(to_str(&
         size_xs)) // ' bytes'

    write(unit_,*) '  Reaction    Q-value   Mult    IE    size(angle) size(energy)'
    do i = 1, nuc % n_reaction
       ! Information on each reaction
       rxn => nuc % reactions(i)

       ! Determine size of angle distribution
       if (rxn % has_angle_dist) then
          size_angle = rxn % adist % n_energy * 16 + size(rxn % adist % data) * 8
       else
          size_angle = 0
       end if

       ! Determine size of energy distribution
       if (rxn % has_energy_dist) then
          size_energy = size(rxn % edist % data) * 8
       else
          size_energy = 0
       end if

       write(unit_,'(3X,A11,1X,F8.3,2X,I4,2X,I6,1X,I11,1X,I11)') &
            reaction_name(rxn % MT), rxn % Q_value, rxn % TY, rxn % IE, &
            size_angle, size_energy

       ! Accumulate data size
       size_total = size_total + size_angle + size_energy
    end do

    ! Write information about URR probability tables
    if (nuc % urr_present) then
       urr => nuc % urr_data
       write(unit_,*) '  Unresolved resonance probability table:'
       write(unit_,*) '    # of energies = ' // trim(to_str(urr % n_energy))
       write(unit_,*) '    # of probabilities = ' // trim(to_str(urr % n_prob))
       write(unit_,*) '    Interpolation =  ' // trim(to_str(urr % interp))
       write(unit_,*) '    Inelastic flag = ' // trim(to_str(urr % inelastic_flag))
       write(unit_,*) '    Absorption flag = ' // trim(to_str(urr % absorption_flag))
       write(unit_,*) '    Multiply by smooth? ', urr % multiply_smooth
       write(unit_,*) '    Min energy = ', trim(to_str(urr % energy(1)))
       write(unit_,*) '    Max energy = ', trim(to_str(urr % energy(urr % n_energy)))
    end if

    ! Write total memory used
    write(unit_,*) '  Total memory used = ' // trim(to_str(size_total)) &
         // ' bytes'

    ! Blank line at end of nuclide
    write(unit_,*)

  end subroutine print_nuclide

!===============================================================================
! PRINT_SUMMARY displays summary information about the problem about to be run
! after reading all input files
!===============================================================================

  subroutine print_summary()

    integer :: i
    character(15) :: string
    type(Material),    pointer :: m => null()
    type(TallyObject), pointer :: t => null()

    ! Display problem summary
    call header("PROBLEM SUMMARY", unit=UNIT_SUMMARY)
    if (problem_type == PROB_CRITICALITY) then
       write(UNIT_SUMMARY,100) 'Problem type:', 'Criticality'
       write(UNIT_SUMMARY,101) 'Number of Cycles:', n_cycles
       write(UNIT_SUMMARY,101) 'Number of Inactive Cycles:', n_inactive
    elseif (problem_type == PROB_SOURCE) then
       write(UNIT_SUMMARY,100) 'Problem type:', 'External Source'
    end if
    write(UNIT_SUMMARY,101) 'Number of Particles:', n_particles

    ! Display geometry summary
    call header("GEOMETRY SUMMARY", unit=UNIT_SUMMARY)
    write(UNIT_SUMMARY,101) 'Number of Cells:', n_cells
    write(UNIT_SUMMARY,101) 'Number of Surfaces:', n_surfaces
    write(UNIT_SUMMARY,101) 'Number of Materials:', n_materials

    ! print summary of all geometry
    call print_geometry()

    ! print summary of materials
    call header("MATERIAL SUMMARY", unit=UNIT_SUMMARY)
    do i = 1, n_materials
       m => materials(i)
       call print_material(m, unit=UNIT_SUMMARY)
    end do

    ! print summary of tallies
    if (n_tallies > 0) then
       call header("TALLY SUMMARY", unit=UNIT_SUMMARY)
       do i = 1, n_tallies
          t=> tallies(i)
          call print_tally(t, unit=UNIT_SUMMARY)
       end do
    end if

    ! print summary of unionized energy grid
    call header("UNIONIZED ENERGY GRID", unit=UNIT_SUMMARY)
    write(UNIT_SUMMARY,*) "Points on energy grid:  " // trim(to_str(n_grid))
    write(UNIT_SUMMARY,*) "Extra storage required: " // trim(to_str(&
         n_grid*n_nuclides_total*4)) // " bytes"

    ! print summary of variance reduction
    call header("VARIANCE REDUCTION", unit=UNIT_SUMMARY)
    if (survival_biasing) then
       write(UNIT_SUMMARY,100) "Survival Biasing:", "on"
    else
       write(UNIT_SUMMARY,100) "Survival Biasing:", "off"
    end if
    string = to_str(weight_cutoff)
    write(UNIT_SUMMARY,100) "Weight Cutoff:", trim(string)
    string = to_str(weight_survive)
    write(UNIT_SUMMARY,100) "Survival weight:", trim(string)

    ! Format descriptor for columns
100 format (1X,A,T35,A)
101 format (1X,A,T35,I11)

  end subroutine print_summary

!===============================================================================
! PRINT_PLOT displays selected options for plotting
!===============================================================================

  subroutine print_plot()

    ! Display header for plotting
    call header("PLOTTING SUMMARY")

    ! Print plotting origin
    write(ou,100) "Plotting Origin:", trim(to_str(plot_origin(1))) // &
         " " // trim(to_str(plot_origin(2))) // " " // &
         trim(to_str(plot_origin(3)))

    ! Print plotting width
    write(ou,100) "Plotting Width:", trim(to_str(plot_width(1))) // &
         " " // trim(to_str(plot_width(2)))

    ! Print pixel width
    write(ou,100) "Pixel Width:", trim(to_str(pixel))
    write(ou,*)

    ! Format descriptor for columns
100 format (1X,A,T25,A)

  end subroutine print_plot

!===============================================================================
! PRINT_RUNTIME displays the total time elapsed for the entire run, for
! initialization, for computation, and for intercycle synchronization.
!===============================================================================

  subroutine print_runtime()

    integer(8)    :: total_particles
    real(8)       :: speed
    character(15) :: string

    ! display header block
    call header("Timing Statistics")

    ! display time elapsed for various sections
    write(ou,100) "Total time for initialization", time_initialize % elapsed
    write(ou,100) "  Reading cross sections", time_read_xs % elapsed
    write(ou,100) "  Unionizing energy grid", time_unionize % elapsed
    write(ou,100) "Total time in computation", time_compute % elapsed
    write(ou,100) "Total time between cycles", time_intercycle % elapsed
    write(ou,100) "  Accumulating tallies", time_ic_tallies % elapsed
    write(ou,100) "  Sampling source sites", time_ic_sample % elapsed
    write(ou,100) "  SEND/RECV source sites", time_ic_sendrecv % elapsed
    write(ou,100) "  Reconstruct source bank", time_ic_rebuild % elapsed
    write(ou,100) "Total time in inactive cycles", time_inactive % elapsed
    write(ou,100) "Total time in active cycles", time_active % elapsed
    write(ou,100) "Total time elapsed", time_total % elapsed

    ! display header block
    call header("Run Statistics")

    ! display calculate rate and final keff
    total_particles = n_particles * n_cycles
    speed = real(total_particles) / time_compute % elapsed
    string = to_str(speed)
    write(ou,101) "Calculation Rate", trim(string)
    write(ou,102) "Final Keff", keff, keff_std
    write(ou,*)

    ! format for write statements
100 format (1X,A,T35,"= ",ES11.4," seconds")
101 format (1X,A,T20,"= ",A," neutrons/second")
102 format (1X,A,T20,"= ",F8.5," +/- ",F8.5)
 
  end subroutine print_runtime

!===============================================================================
! CREATE_SUMMARY_FILE opens the summary.out file for logging information about
! the simulation
!===============================================================================

  subroutine create_summary_file()

    integer :: io_error
    logical :: file_exists  ! does log file already exist?
    character(MAX_FILE_LEN) :: path ! path of summary file

    ! Create filename for log file
    path = "summary.out"

    ! Check if log file already exists
    inquire(FILE=path, EXIST=file_exists)
    if (file_exists) then
       ! Possibly copy old log file
    end if

    ! Open log file for writing
    open(UNIT=UNIT_SUMMARY, FILE=path, STATUS='replace', &
         ACTION='write', IOSTAT=io_error)

  end subroutine create_summary_file

end module output