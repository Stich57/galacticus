!! Copyright 2009, 2010, 2011, 2012, 2013, 2014, 2015, 2016, 2017, 2018,
!!           2019, 2020, 2021
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

  !% Implementation of a ``linear'' solver for galactic structure (no self-gravity of baryons, and size simply scales in
  !% proportion to specific angular momentum).

  use :: Dark_Matter_Halo_Scales, only : darkMatterHaloScale, darkMatterHaloScaleClass

  !# <galacticStructureSolver name="galacticStructureSolverLinear">
  !#  <description>
  !#   A galactic structure solver class that determines the sizes of galactic components by assuming that radius scales linearly
  !#   with specific angular momentum such that
  !#   \begin{equation}
  !#    r = r_\mathrm{vir} j/j_\mathrm{vir}
  !#   \end{equation}
  !#   where $j$ is the specific angular momentum of the \gls{component} (at whatever point in the profile is to be solved for),
  !#   $r$ is radius, $r_\mathrm{vir}$ is the virial radius of the \gls{node} and $j_\mathrm{vir}= r_\mathrm{vir} v_\mathrm{vir}$
  !#   with $v_\mathrm{vir}$ being the virial velocity of the \gls{node}.
  !#  </description>
  !# </galacticStructureSolver>
  type, extends(galacticStructureSolverClass) :: galacticStructureSolverLinear
     !% Implementation of a ``linear'' solver for galactic structure (no self-gravity of baryons, and size simply scales in
     !% proportion to specific angular momentum).
     private
     class  (darkMatterHaloScaleClass), pointer :: darkMatterHaloScale_
   contains
     final     ::             linearDestructor
     procedure :: solve    => linearSolve
     procedure :: revert   => linearRevert
     procedure :: autoHook => linearAutoHook
  end type galacticStructureSolverLinear

  interface galacticStructureSolverLinear
     !% Constructors for the {\normalfont \ttfamily linear} galactic structure solver class.
     module procedure linearConstructorParameters
     module procedure linearConstructorInternal
  end interface galacticStructureSolverLinear

contains

  function linearConstructorParameters(parameters) result(self)
    !% Constructor for the {\normalfont \ttfamily linear} galactic structure solver class which takes a
    !% parameter set as input.
    use :: Input_Parameters, only : inputParameter, inputParameters
    implicit none
    type   (galacticStructureSolverLinear)                :: self
    type   (inputParameters              ), intent(inout) :: parameters
    class  (darkMatterHaloScaleClass     ), pointer       :: darkMatterHaloScale_

    !# <objectBuilder class="darkMatterHaloScale" name="darkMatterHaloScale_" source="parameters"/>
    self=galacticStructureSolverLinear(darkMatterHaloScale_)
    !# <inputParametersValidate source="parameters"/>
    !# <objectDestructor name="darkMatterHaloScale_"/>
    return
  end function linearConstructorParameters

  function linearConstructorInternal(darkMatterHaloScale_) result(self)
    !% Internal constructor for the {\normalfont \ttfamily linear} galactic structure solver class.
    implicit none
    type   (galacticStructureSolverLinear)                        :: self
    class  (darkMatterHaloScaleClass     ), intent(in   ), target :: darkMatterHaloScale_
    !# <constructorAssign variables="*darkMatterHaloScale_"/>

    return
  end function linearConstructorInternal

  subroutine linearAutoHook(self)
    !% Attach to various event hooks.
    use :: Events_Hooks, only : nodePromotionEvent  , openMPThreadBindingAtLevel, postEvolveEvent, preDerivativeEvent, &
          &                     satelliteMergerEvent, dependencyDirectionAfter  , dependencyRegEx
    implicit none
    class(galacticStructureSolverLinear), intent(inout) :: self
    type (dependencyRegEx              ), dimension(1)  :: dependencies

    dependencies(1)=dependencyRegEx(dependencyDirectionAfter,'^nodeComponent')
    call   preDerivativeEvent%attach(self,linearSolvePreDeriativeHook,openMPThreadBindingAtLevel                                                        )
    call      postEvolveEvent%attach(self,linearSolveHook            ,openMPThreadBindingAtLevel,label='structureSolverLinear',dependencies=dependencies)
    call satelliteMergerEvent%attach(self,linearSolveHook            ,openMPThreadBindingAtLevel,label='structureSolverLinear',dependencies=dependencies)
    call   nodePromotionEvent%attach(self,linearSolveHook            ,openMPThreadBindingAtLevel,label='structureSolverLinear',dependencies=dependencies)
    return
  end subroutine linearAutoHook

  subroutine linearDestructor(self)
    !% Destructor for the {\normalfont \ttfamily linear} galactic structure solver class.
    use :: Events_Hooks, only : nodePromotionEvent, postEvolveEvent, preDerivativeEvent, satelliteMergerEvent
    implicit none
    type(galacticStructureSolverLinear), intent(inout) :: self

    !# <objectDestructor name="self%darkMatterHaloScale_"/>
    call   preDerivativeEvent%detach(self,linearSolvePreDeriativeHook)
    call      postEvolveEvent%detach(self,linearSolveHook            )
    call satelliteMergerEvent%detach(self,linearSolveHook            )
    call   nodePromotionEvent%detach(self,linearSolveHook            )
    return
  end subroutine linearDestructor

  subroutine linearSolveHook(self,node)
    !% Hookable wrapper around the solver.
    use :: Galacticus_Error, only : Galacticus_Error_Report
    implicit none
    class(*       ), intent(inout)         :: self
    type (treeNode), intent(inout), target :: node

    select type (self)
    type is (galacticStructureSolverLinear)
       call self%solve(node)
    class default
       call Galacticus_Error_Report('incorrect class'//{introspection:location})
    end select
    return
  end subroutine linearSolveHook

  subroutine linearSolvePreDeriativeHook(self,node,propertyType)
    !% Hookable wrapper around the solver.
    use :: Galacticus_Error, only : Galacticus_Error_Report
    implicit none
    class  (*       ), intent(inout)         :: self
    type   (treeNode), intent(inout), target :: node
    integer          , intent(in   )         :: propertyType
    !$GLC attributes unused :: propertyType

    select type (self)
    type is (galacticStructureSolverLinear)
       call self%solve(node)
    class default
       call Galacticus_Error_Report('incorrect class'//{introspection:location})
    end select
    return
  end subroutine linearSolvePreDeriativeHook

  subroutine linearSolve(self,node)
    !% Solve for the structure of galactic components assuming no self-gravity of baryons, and that size simply scales in
    !% proportion to specific angular momentum.
    include 'galactic_structure.radius_solver.tasks.modules.inc'
    include 'galactic_structure.radius_solver.plausible.modules.inc'
    implicit none
    class           (galacticStructureSolverLinear), intent(inout)         :: self
    type            (treeNode                     ), intent(inout), target :: node
    logical                                        , parameter             :: specificAngularMomentumRequired=.true.
    procedure       (solverGet                    ), pointer               :: radiusGet                             , velocityGet
    procedure       (solverSet                    ), pointer               :: radiusSet                             , velocitySet
    logical                                                                :: componentActive
    double precision                                                       :: specificAngularMomentum

    ! Check that the galaxy is physical plausible. In this linear solver, we don't act on this.
    node%isPhysicallyPlausible=.true.
    node%isSolvable           =.true.
    include 'galactic_structure.radius_solver.plausible.inc'
    include 'galactic_structure.radius_solver.tasks.inc'
    return

  contains

    subroutine radiusSolve(node,specificAngularMomentum,radiusGet,radiusSet,velocityGet,velocitySet)
      !% Solve for the equilibrium radius of the given component.
      implicit none
      type            (treeNode ), intent(inout)          :: node
      double precision           , intent(in   )          :: specificAngularMomentum
      procedure       (solverGet), intent(in   ), pointer :: radiusGet              , velocityGet
      procedure       (solverSet), intent(in   ), pointer :: radiusSet              , velocitySet
      double precision                                    :: radius                 , velocity
      !$GLC attributes unused :: radiusGet, velocityGet

      ! Return immediately if the specific angular momentum is zero.
      if (specificAngularMomentum <= 0.0d0) return
      ! Find the radius of the component, assuming radius scales linearly with angular momentum.
      velocity=self%darkMatterHaloScale_%virialVelocity(node)
      radius  =specificAngularMomentum/velocity
      ! Set the component size to new radius and velocity.
      call radiusSet  (node,radius  )
      call velocitySet(node,velocity)
      return
    end subroutine radiusSolve

  end subroutine linearSolve

  subroutine linearRevert(self,node)
    !% Revert radii for the linear galactic structure solve. Not necessary for this algorithm.
    implicit none
    class(galacticStructureSolverLinear), intent(inout) :: self
    type (treeNode                     ), intent(inout) :: node
    !$GLC attributes unused :: self, node

    return
  end subroutine linearRevert
