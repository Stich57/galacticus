!! Copyright 2009, 2010, 2011, 2012, 2013, 2014, 2015, 2016, 2017, 2018,
!!           2019
!!    Andrew Benson <abenson@carnegiescience.edu>
!!
!! This file is part of Galacticus.
!!
!!    Galacticus is free software: you can redistribute it and/or modify
!!    it under the terms of the GNU General Public License as published by
!!    the Free Software Foundation, either version 3 of the License, or
!!    (at your option) any later version.
!!
!!    Galacticus is distributed in the hope that it will be useful,
!!    but WITHOUT ANY WARRANTY; without even the implied warranty of
!!    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
!!    GNU General Public License for more details.
!!
!!    You should have received a copy of the GNU General Public License
!!    along with Galacticus.  If not, see <http://www.gnu.org/licenses/>.

!% Contains a module which implements an equilibrium galactic radii solver.

module Galactic_Structure_Radii_Equilibrium
  !% Implements an equilibrium galactic radii solver.
  use Galactic_Structure_Radius_Solver_Procedures
  implicit none
  private
  public :: Galactic_Structure_Radii_Equilibrium_Initialize

  ! Parameter controlling the accuracy of the solutions sought.
  double precision                                      :: equilibriumStructureSolutionTolerance

  ! Module variables used to communicate current state of radius solver.
  integer                                               :: activeComponentCount                              , iterationCount
  double precision                                      :: fitMeasure
  type            (treeNode), pointer                   :: haloNode
  double precision          , allocatable, dimension(:) :: radiusStored                                      , velocityStored
  logical                                               :: revertStructure                           =.false.
  !$omp threadprivate(iterationCount,activeComponentCount,fitMeasure,haloNode,radiusStored,velocityStored,revertStructure)
  ! Options controlling the solver.
  logical                                               :: equilibriumStructureIncludeBaryonGravity        , equilibriumStructureUseFormationHalo

contains

  !# <galacticStructureRadiusSolverMethod>
  !#  <unitName>Galactic_Structure_Radii_Equilibrium_Initialize</unitName>
  !# </galacticStructureRadiusSolverMethod>
  subroutine Galactic_Structure_Radii_Equilibrium_Initialize(galacticStructureRadiusSolverMethod,Galactic_Structure_Radii_Solve_Do,Galactic_Structure_Radii_Revert_Do)
    !% Initializes the ``equilibrium'' galactic radii solver module.
    use Input_Parameters
    use ISO_Varying_String
    implicit none
    type     (varying_string                             ), intent(in   )          :: galacticStructureRadiusSolverMethod
    procedure(Galactic_Structure_Radii_Solve_Equilibrium ), intent(inout), pointer :: Galactic_Structure_Radii_Solve_Do
    procedure(Galactic_Structure_Radii_Revert_Equilibrium), intent(inout), pointer :: Galactic_Structure_Radii_Revert_Do

    if (galacticStructureRadiusSolverMethod == 'equilibrium') then
       Galactic_Structure_Radii_Solve_Do  => Galactic_Structure_Radii_Solve_Equilibrium
       Galactic_Structure_Radii_Revert_Do => Galactic_Structure_Radii_Revert_Equilibrium
       ! Get parameters of the model.
       !# <inputParameter>
       !#   <name>equilibriumStructureIncludeBaryonGravity</name>
       !#   <cardinality>1</cardinality>
       !#   <defaultValue>.true.</defaultValue>
       !#   <description>Specifies whether or not gravity from baryons is included when solving for sizes of galactic components in equilibriumally contracted dark matter halos.</description>
       !#   <source>globalParameters</source>
       !#   <type>boolean</type>
       !# </inputParameter>
       !# <inputParameter>
       !#   <name>equilibriumStructureUseFormationHalo</name>
       !#   <cardinality>1</cardinality>
       !#   <defaultValue>.false.</defaultValue>
       !#   <description>Specifies whether or not the ``formation halo'' should be used when solving for the radii of galaxies.</description>
       !#   <source>globalParameters</source>
       !#   <type>boolean</type>
       !# </inputParameter>
       !# <inputParameter>
       !#   <name>equilibriumStructureSolutionTolerance</name>
       !#   <cardinality>1</cardinality>
       !#   <defaultValue>1.0d-2</defaultValue>
       !#   <description>Maximum allowed mean fractional error in the radii of all components when seeking equilibrium solutions for galactic structure.</description>
       !#   <source>globalParameters</source>
       !#   <type>real</type>
       !# </inputParameter>
    end if
    return
  end subroutine Galactic_Structure_Radii_Equilibrium_Initialize

  subroutine Galactic_Structure_Radii_Solve_Equilibrium(node)
    !% Find the radii of galactic components in {\normalfont \ttfamily node} using the ``equilibrium'' method.
    use Galacticus_Error
    use Galacticus_Display
    use Galacticus_Nodes    , only : treeNode
    include 'galactic_structure.radius_solver.tasks.modules.inc'
    include 'galactic_structure.radius_solver.plausible.modules.inc'
    implicit none
    type            (treeNode                  ), intent(inout), target :: node
    integer                                     , parameter             :: iterationMaximum                =  100
    procedure       (Radius_Solver_Get_Template), pointer               :: Radius_Get                      => null(), Velocity_Get => null()
    procedure       (Radius_Solver_Set_Template), pointer               :: Radius_Set                      => null(), Velocity_Set => null()
    !$omp threadprivate(Radius_Get,Radius_Set,Velocity_Get,Velocity_Set)
    logical                                     , parameter             :: specificAngularMomentumRequired =  .true.
    logical                                                             :: componentActive
    double precision                                                    :: specificAngularMomentum

    ! Check that the galaxy is physical plausible. If not, do not try to solve for its structure.
    node%isPhysicallyPlausible=.true.
    node%isSolvable           =.true.
    include 'galactic_structure.radius_solver.plausible.inc'
    if (node%isPhysicallyPlausible) then
       ! Initialize the solver state.
       iterationCount=0
       fitMeasure    =2.0d0*equilibriumStructureSolutionTolerance

       ! Determine which node to use for halo properties.
       if (equilibriumStructureUseFormationHalo) then
          if (.not.associated(node%formationNode)) call Galacticus_Error_Report('no formation node exists'//{introspection:location})
          haloNode => node%formationNode
       else
          haloNode => node
       end if

       ! Begin iteration to find a converged solution.
       do while (iterationCount <= 2 .or. ( fitMeasure > equilibriumStructureSolutionTolerance .and. iterationCount < iterationMaximum ) )
          iterationCount      =iterationCount+1
          activeComponentCount=0
          if (iterationCount > 1) fitMeasure=0.0d0
          include 'galactic_structure.radius_solver.tasks.inc'
          ! Check that we have some active components.
          if (activeComponentCount == 0) then
             fitMeasure=0.0d0
             exit
          else
             ! Normalize the fit measure by the number of active components.
             fitMeasure=fitMeasure/dble(activeComponentCount)
          end if
       end do
       ! Check that we found a converged solution.
       if (fitMeasure > equilibriumStructureSolutionTolerance) then
          call Galacticus_Display_Message('dumping node for which radii are currently being sought')
          call node%serializeASCII()
          call Galacticus_Error_Report('failed to find converged solution'//{introspection:location})
       end if
    end if
    ! Unset structure reversion flag.
    revertStructure=.false.
    return
  end subroutine Galactic_Structure_Radii_Solve_Equilibrium

  subroutine Solve_For_Radius(node,specificAngularMomentum,Radius_Get,Radius_Set,Velocity_Get,Velocity_Set)
    !% Solve for the equilibrium radius of the given component.
    use Dark_Matter_Profiles_DMO
    use Dark_Matter_Profiles
    use Numerical_Constants_Physical
    use Galactic_Structure_Rotation_Curves
    use Galactic_Structure_Options
    use Galacticus_Error
    use ISO_Varying_String
    use String_Handling
    use Memory_Management
    use Galacticus_Display
    implicit none
    type            (treeNode                  ), intent(inout)                     :: node
    double precision                            , intent(in   )                     :: specificAngularMomentum
    procedure       (Radius_Solver_Get_Template), intent(in   ) , pointer           :: Radius_Get                          , Velocity_Get
    procedure       (Radius_Solver_Set_Template), intent(in   ) , pointer           :: Radius_Set                          , Velocity_Set
    class           (darkMatterProfileDMOClass )                , pointer           :: darkMatterProfileDMO_
    class           (darkMatterProfileClass    )                , pointer           :: darkMatterProfile_
    double precision                            , dimension(:,:), allocatable, save :: radiusHistory
    !$omp threadprivate(radiusHistory)
    double precision                            , dimension(:,:), allocatable       :: radiusHistoryTemporary
    double precision                            , dimension(:  ), allocatable       :: radiusStoredTmp                     , velocityStoredTmp
    integer                                     , dimension(1  ), parameter         :: storeIncrement                 =[10]
    integer                                     , parameter                         :: iterationsForBisectionMinimum  = 10
    integer                                     , parameter                         :: activeComponentMaximumIncrement=  2
    integer                                                                         :: activeComponentMaximumCurrent
    character       (len=14                    )                                    :: label
    type            (varying_string            )                                    :: message
    double precision                                                                :: baryonicVelocitySquared             , darkMatterMassFinal, &
         &                                                                             darkMatterVelocitySquared               , &
         &                                                                             radius                              , radiusNew          , &
         &                                                                             velocity

    ! Get required objects.
    darkMatterProfileDMO_ => darkMatterProfileDMO()
    ! Count the number of active comonents.
    activeComponentCount=activeComponentCount+1

    if (iterationCount == 1) then       
       ! If structure is to be reverted, do so now.
       if (revertStructure.and.allocated(radiusStored)) then
          call   Radius_Set(node,  radiusStored(activeComponentCount))
          call Velocity_Set(node,velocityStored(activeComponentCount))
       end if
       ! On first iteration, see if we have a previous radius set for this component.
       radius=Radius_Get(node)
       if (radius <= 0.0d0) then
          ! No previous radius was set, so make a simple estimate of sizes of all components ignoring equilibrium contraction and self-gravity.

          ! Find the radius in the dark matter profile with the required specific angular momentum
          radius=darkMatterProfileDMO_%radiusFromSpecificAngularMomentum(haloNode,specificAngularMomentum)

          ! Find the velocity at this radius.
          velocity=darkMatterProfileDMO_%circularVelocity(haloNode,radius)
       else
          ! A previous radius was set, so use it, and the previous circular velocity, as the initial guess.
          velocity=Velocity_Get(node)
       end if
       ! If structure is not being reverted, store the new values of radius and velocity.
       if (.not.revertStructure .and. iterationCount == 1) then
          ! Store these quantities.
          if (.not.allocated(radiusStored)) then
             call allocateArray(  radiusStored,storeIncrement)
             call allocateArray(velocityStored,storeIncrement)
             radiusStored  =0.0d0
             velocityStored=0.0d0
          else if (activeComponentCount > size(radiusStored)) then
             call move_alloc     (  radiusStored,        radiusStoredTmp                )
             call move_alloc     (velocityStored,      velocityStoredTmp                )
             call allocateArray  (  radiusStored,shape(  radiusStoredTmp)+storeIncrement)
             call allocateArray  (velocityStored,shape(velocityStoredTmp)+storeIncrement)
             radiusStored  (                        1:size(  radiusStoredTmp))=  radiusStoredTmp
             velocityStored(                        1:size(velocityStoredTmp))=velocityStoredTmp
             radiusStored  (size(  radiusStoredTmp)+1:size(  radiusStored   ))=0.0d0
             velocityStored(size(velocityStoredTmp)+1:size(velocityStored   ))=0.0d0
             call deallocateArray(  radiusStoredTmp)
             call deallocateArray(velocityStoredTmp)
          end if
          radiusStored  (activeComponentCount)=radius
          velocityStored(activeComponentCount)=velocity
       end if

    else
       ! On subsequent iterations do the full calculation providing component has non-zero specific angular momentum.
       if (specificAngularMomentum <= 0.0d0) return

       ! Get current radius of the component.
       radius=Radius_Get(node)

       ! Find the enclosed mass in the dark matter halo.
       darkMatterProfile_  => darkMatterProfile              (               )
       darkMatterMassFinal =  darkMatterProfile_%enclosedMass(haloNode,radius)
       
       ! Compute dark matter contribution to rotation curve.
       darkMatterVelocitySquared=gravitationalConstantGalacticus*darkMatterMassFinal/radius

       ! Compute baryonic contribution to rotation curve.
       if (equilibriumStructureIncludeBaryonGravity) then
          baryonicVelocitySquared=Galactic_Structure_Rotation_Curve(node,radius,massType=massTypeBaryonic)**2
       else
          baryonicVelocitySquared=0.0d0
       end if

       ! Compute new estimate of velocity.
       velocity=sqrt(darkMatterVelocitySquared+baryonicVelocitySquared)

       ! Compute new estimate of radius.
       if (radius > 0.0d0) then
          radiusNew=sqrt(specificAngularMomentum/velocity*radius)
       else
          radiusNew=     specificAngularMomentum/velocity
       endif
       
       ! Ensure that the radius history array is sufficiently sized.
       if (.not.allocated(radiusHistory)) then
          call allocateArray(radiusHistory,[2,activeComponentCount+activeComponentMaximumIncrement])
          radiusHistory=-1.0d0
       else if (size(radiusHistory,dim=2) < activeComponentCount) then
          activeComponentMaximumCurrent=size(radiusHistory,dim=2)
          call Move_Alloc(radiusHistory,radiusHistoryTemporary)
          call allocateArray(radiusHistory,[2,activeComponentCount+activeComponentMaximumIncrement])
          radiusHistory(:,                              1:                     activeComponentMaximumCurrent  )=radiusHistoryTemporary
          radiusHistory(:,activeComponentMaximumCurrent+1:activeComponentCount+activeComponentMaximumIncrement)=-1.0d0
          call deallocateArray(radiusHistoryTemporary)
       end if
       ! Detect oscillations in the radius solver. Only do this after a few bisection iterations have passed as we don't want to
       ! declare a true oscillation until the solver has had time to "burn in".
       if (iterationCount == 1) radiusHistory=-1.0d0
       if     (                                                                                                                                                                        &
            &             iterationCount                                                                                                              > iterationsForBisectionMinimum  &
            &  .and. all( radiusHistory(:,activeComponentCount)                                                                                       >= 0.0d0                       ) &
            &  .and.     (radiusHistory(2,activeComponentCount)-radiusHistory(1,activeComponentCount))*(radiusHistory(1,activeComponentCount)-radius) <  0.0d0                         &
            & ) then
          ! An oscillation has been detected - attempt to break out of it. The following heuristic has been found to work quite
          ! well - we bisect previous solutions in the oscillating sequence in a variety of different ways
          ! (arithmetic/geometric and using the current+previous or two previous solutions), alternating the bisection method
          ! sequentially. There's no guarantee that this will work in every situation however.
          select case (mod(iterationCount,4))
          case (0)
             radius=sqrt  (radius                               *radiusHistory(1,activeComponentCount))
          case (1)
             radius=0.5d0*(radius                               +radiusHistory(1,activeComponentCount))
          case (2)
             radius=sqrt  (radiusHistory(1,activeComponentCount)*radiusHistory(2,activeComponentCount))
          case (3)
             radius=0.5d0*(radiusHistory(1,activeComponentCount)+radiusHistory(2,activeComponentCount))
          end select
          radiusHistory(:,activeComponentCount)=-1.0d0
       end if
       radiusHistory(2,activeComponentCount)=radiusHistory(1,activeComponentCount)
       radiusHistory(1,activeComponentCount)=radius

       ! Compute a fit measure.
       if (radius > 0.0d0 .and. radiusNew > 0.0d0) fitMeasure=fitMeasure+abs(log(radiusNew/radius))

       ! Set radius to new radius.
       radius=radiusNew

       ! Catch unphysical states.
       if (radius <= 0.0d0) then
          if (Galacticus_Verbosity_Level() < verbosityStandard) call Galacticus_Verbosity_Level_Set(verbosityStandard)
          call node%serializeASCII()
          message='radius has reached zero for node '
          message=message//node%index()//' - report follows:'//char(10)
          write (label,'(e12.6)') specificAngularMomentum
          message=message//'  specific angular momentum:    '//label//char(10)
          write (label,'(e12.6)') velocity
          message=message//'  rotation velocity:            '//label//char(10)
          write (label,'(e12.6)') sqrt(darkMatterVelocitySquared)
          message=message//'   -> dark matter contribution: '//label//char(10)
          write (label,'(e12.6)') sqrt(baryonicVelocitySquared  )
          message=message//'   -> baryonic contribution:    '//label
          call Galacticus_Error_Report(message//{introspection:location})
       end if

    end if

    ! Set the component size to new radius and velocity.
    call   Radius_Set(node,radius  )
    call Velocity_Set(node,velocity)
     return
  end subroutine Solve_For_Radius

  subroutine Galactic_Structure_Radii_Revert_Equilibrium(node)
    !% Revert radii for the equilibrium galactic structure solve.
    implicit none
    type(treeNode), intent(inout), target :: node
    !GCC$ attributes unused :: node

    ! Simply record that reversion should be performed on the next call to the solver.
    revertStructure=.true.
    return
  end subroutine Galactic_Structure_Radii_Revert_Equilibrium

end module Galactic_Structure_Radii_Equilibrium