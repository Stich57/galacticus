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

  !% Implementation of a simple ram pressure stripping for spherically-symmetric systems.

  use :: Hot_Halo_Ram_Pressure_Forces, only : hotHaloRamPressureForceClass

  !# <ramPressureStripping name="ramPressureStrippingSimpleSpherical">
  !#  <description>A simple model of ram pressure stripping in spherically-symmetric systems.</description>
  !# </ramPressureStripping>
  type, extends(ramPressureStrippingClass) :: ramPressureStrippingSimpleSpherical
     !% Implementation of a simple model of ram pressure stripping in spherically-symmetric systems.
     private
     class           (hotHaloRamPressureForceClass), pointer :: hotHaloRamPressureForce_ => null()
     double precision                                        :: rateFractionalMaximum
   contains
     final     ::                 simpleSphericalDestructor
     procedure :: rateMassLoss => simpleSphericalRateMassLoss
  end type ramPressureStrippingSimpleSpherical

  interface ramPressureStrippingSimpleSpherical
     !% Constructors for the {\normalfont \ttfamily simpleSpherical} model of ram pressure stripping of spheroids class.
     module procedure simpleSphericalConstructorParameters
     module procedure simpleSphericalConstructorInternal
  end interface ramPressureStrippingSimpleSpherical

contains

  function simpleSphericalConstructorParameters(parameters) result(self)
    !% Constructor for the {\normalfont \ttfamily simpleSpherical} timescale for star formation feedback in spheroids class which
    !% takes a parameter set as input.
    use :: Input_Parameters, only : inputParameter, inputParameters
    implicit none
    type            (ramPressureStrippingSimpleSpherical)                :: self
    type            (inputParameters                    ), intent(inout) :: parameters
    class           (hotHaloRamPressureForceClass       ), pointer       :: hotHaloRamPressureForce_
    double precision                                                     :: rateFractionalMaximum

    !# <inputParameter>
    !#   <name>rateFractionalMaximum</name>
    !#   <defaultValue>10.0d0</defaultValue>
    !#   <description>The maximum fractional mass loss rate per dynamical time in the simple model of mass loss from spherically-symmetric due to ram pressure stripping.</description>
    !#   <source>parameters</source>
    !# </inputParameter>
    !# <objectBuilder class="hotHaloRamPressureForce" name="hotHaloRamPressureForce_" source="parameters"/>
    self=ramPressureStrippingSimpleSpherical(rateFractionalMaximum,hotHaloRamPressureForce_)
    !# <inputParametersValidate source="parameters"/>
    !# <objectDestructor name="hotHaloRamPressureForce_"/>
    return
  end function simpleSphericalConstructorParameters

  function simpleSphericalConstructorInternal(rateFractionalMaximum,hotHaloRamPressureForce_) result(self)
    !% Internal constructor for the {\normalfont \ttfamily simpleSpherical} model of ram pressure stripping of spheroids class.
    implicit none
    type            (ramPressureStrippingSimpleSpherical)                        :: self
    double precision                                     , intent(in   )         :: rateFractionalMaximum
    class           (hotHaloRamPressureForceClass       ), intent(in   ), target :: hotHaloRamPressureForce_
    !# <constructorAssign variables="rateFractionalMaximum, *hotHaloRamPressureForce_"/>

    return
  end function simpleSphericalConstructorInternal

  subroutine simpleSphericalDestructor(self)
    !% Destructor for the {\normalfont \ttfamily simpleSpherical} model of ram pressure stripping of spheroids class.
    implicit none
    type(ramPressureStrippingSimpleSpherical), intent(inout) :: self

    !# <objectDestructor name="self%hotHaloRamPressureForce_"/>
    return
  end subroutine simpleSphericalDestructor

  double precision function simpleSphericalRateMassLoss(self,component)
    !% Computes the mass loss rate from spherically-symmetric systems due to ram pressure stripping assuming a simple model. Specifically, the mass loss
    !% rate is
    !% \begin{equation}
    !% \dot{M}_\mathrm{gas} = -\alpha M_\mathrm{gas}/\tau,
    !% \end{equation}
    !% where
    !% \begin{equation}
    !% \alpha = F_\mathrm{ram}/F_\mathrm{gravity},
    !% \end{equation}
    !% $F_\mathrm{ram}$ is the ram pressure force from the hot halo (see \refPhysics{hotHaloRamPressureForce}), and
    !% \begin{equation}
    !% F_\mathrm{gravity} = {4\over 3} \rho_\mathrm{gas}(r_{1/2}) {\mathrm{G} M_\mathrm{total}(r_{1/2})\over r_{1/2}}
    !% \end{equation}
    !% is the gravitational restoring force at the half-mass radius, $r_\mathrm{1/2}$ \citep{takeda_ram_1984}.
    use :: Galactic_Structure_Densities      , only : Galactic_Structure_Density
    use :: Galactic_Structure_Enclosed_Masses, only : Galactic_Structure_Enclosed_Mass
    use :: Galactic_Structure_Options        , only : componentTypeSpheroid           , coordinateSystemSpherical, massTypeAll, massTypeGaseous
    use :: Galacticus_Nodes                  , only : nodeComponentSpheroid           , treeNode
    use :: Numerical_Constants_Astronomical  , only : gigaYear                        , megaParsec
    use :: Numerical_Constants_Astronomical  , only : gravitationalConstantGalacticus
    use :: Numerical_Constants_Prefixes      , only : kilo
    implicit none
    class           (ramPressureStrippingSimpleSpherical), intent(inout) :: self
    class           (nodeComponent                      ), intent(inout) :: component
    type            (treeNode                           ), pointer       :: node
    integer                                                              :: componentType
    double precision                                                     :: forceGravitational    , forceRamPressure, &
         &                                                                  rateMassLossFractional, radiusHalfMass  , &
         &                                                                  densityGas            , massHalf        , &
         &                                                                  timeDynamical         , radius          , &
         &                                                                  radiusHalfMass        , velocity        , &
         &                                                                  massGas

    ! Assume no mass loss rate due to ram pressure by default.
    simpleSphericalRateMassLoss=0.0d0
    ! Return immediately if this is not a satellite.
    node => component%hostNode
    if (.not.node%isSatellite()) return
    ! Get the ram pressure force due to the hot halo.
    forceRamPressure=self%hotHaloRamPressureForce_%force(node)
    ! Get required properties.
    select type (component)
    class is (nodeComponentSpheroid)
       componentType =componentTypeSpheroid
       radius        =component%radius        ()
       radiusHalfMass=component%halfMassRadius()
       velocity      =component%velocity      ()
       massGas       =component%massGas       ()
    class default
       componentType =0
       radius        =0.0d0
       radiusHalfMass=0.0d0
       velocity      =0.0d0
       massGas       =0.0d0
       call Galacticus_Error_Report('unsupported component'//{introspection:location})
    end select
    ! Compute the densities at the half mass radius.
    densityGas          =  Galactic_Structure_Density      (                                            &
         &                                                  node                                      , &
         &                                                  [radiusHalfMass,0.0d0,0.0d0]              , &
         &                                                  coordinateSystem=coordinateSystemSpherical, &
         &                                                  massType        =massTypeGaseous          , &
         &                                                  componentType   =componentType              &
         &                                                 )
    massHalf            =  Galactic_Structure_Enclosed_Mass(                                            &
         &                                                  node                                      , &
         &                                                  radiusHalfMass                            , &
         &                                                  massType        =massTypeAll              , &
         &                                                  componentType   =componentType              &
         &                                                 )
    ! Compute the gravitational restoring force.
    forceGravitational  =  +4.0d0                           &
         &                 *gravitationalConstantGalacticus &
         &                 *densityGas                      &
         &                 *massHalf                        &
         &                 /3.0d0                           &
         &                 /radiusHalfMass
    ! Return zero rate if the gravitational force is zero.
    if (forceGravitational <= 0.0d0) return
    ! Compute the mass loss fraction per dynamical time.
    if (forceRamPressure < self%rateFractionalMaximum*forceGravitational) then
       rateMassLossFractional=forceRamPressure/forceGravitational
    else
       rateMassLossFractional=self%rateFractionalMaximum
    end if
    ! Compute the dynamical time.
    timeDynamical              =+megaParsec             &
         &                      /kilo                   &
         &                      /gigaYear               &
         &                      *radius                 &
         &                      /velocity
    ! Compute the mass loss rate.
    simpleSphericalRateMassLoss=+rateMassLossFractional &
         &                      *massGas                &
         &                      /timeDynamical
    return
  end function simpleSphericalRateMassLoss
