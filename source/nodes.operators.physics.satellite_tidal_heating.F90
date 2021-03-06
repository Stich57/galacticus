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

  !% Implements a node operator class that applies tidal mass loss to orbiting satellite halos.

  use :: Satellite_Tidal_Heating, only : satelliteTidalHeatingRateClass

  !# <nodeOperator name="nodeOperatorSatelliteTidalHeating">
  !#  <description>A node operator class that applies tidal mass loss to orbiting satellite halos.</description>
  !# </nodeOperator>
  type, extends(nodeOperatorClass) :: nodeOperatorSatelliteTidalHeating
     !% A node operator class that applies tidal mass loss to orbiting satellite halos.
     private
     class(satelliteTidalHeatingRateClass), pointer :: satelliteTidalHeatingRate_ => null()
   contains
     final     ::                          satelliteTidalHeatingRateDestructor
     procedure :: differentialEvolution => satelliteTidalHeatingRateDifferentialEvolution
  end type nodeOperatorSatelliteTidalHeating
  
  interface nodeOperatorSatelliteTidalHeating
     !% Constructors for the {\normalfont \ttfamily satelliteTidalHeatingRate} node operator class.
     module procedure satelliteTidalHeatingRateConstructorParameters
     module procedure satelliteTidalHeatingRateConstructorInternal
  end interface nodeOperatorSatelliteTidalHeating
  
contains

  function satelliteTidalHeatingRateConstructorParameters(parameters) result(self)
    !% Constructor for the {\normalfont \ttfamily satelliteTidalHeatingRate} node operator class which takes a parameter set as input.
    use :: Input_Parameters, only : inputParameters
    implicit none
    type (nodeOperatorSatelliteTidalHeating)                :: self
    type (inputParameters                  ), intent(inout) :: parameters
    class(satelliteTidalHeatingRateClass   ), pointer       :: satelliteTidalHeatingRate_
    
    !# <objectBuilder class="satelliteTidalHeatingRate" name="satelliteTidalHeatingRate_" source="parameters"/>
    self=nodeOperatorSatelliteTidalHeating(satelliteTidalHeatingRate_)
    !# <inputParametersValidate source="parameters"/>
    !# <objectDestructor name="satelliteTidalHeatingRate_"/>
    return
  end function satelliteTidalHeatingRateConstructorParameters

  function satelliteTidalHeatingRateConstructorInternal(satelliteTidalHeatingRate_) result(self)
    !% Internal constructor for the {\normalfont \ttfamily satelliteTidalHeatingRate} node operator class.
    implicit none
    type (nodeOperatorSatelliteTidalHeating)                        :: self
    class(satelliteTidalHeatingRateClass   ), intent(in   ), target :: satelliteTidalHeatingRate_
    !# <constructorAssign variables="*satelliteTidalHeatingRate_"/>

    return
  end function satelliteTidalHeatingRateConstructorInternal

  subroutine satelliteTidalHeatingRateDestructor(self)
    !% Destructor for the {\normalfont \ttfamily satelliteTidalHeatingRate} node operator class.
    implicit none
    type(nodeOperatorSatelliteTidalHeating), intent(inout) :: self

    !# <objectDestructor name="self%satelliteTidalHeatingRate_"/>
    return
  end subroutine satelliteTidalHeatingRateDestructor
  
  subroutine satelliteTidalHeatingRateDifferentialEvolution(self,node,interrupt,functionInterrupt,propertyType)
    !% Perform mass loss from a satellite due to tidal stripping.
    use :: Galacticus_Nodes                , only : nodeComponentSatellite
    use :: Galactic_Structure_Tidal_Tensors, only : Galactic_Structure_Tidal_Tensor
    use :: Numerical_Constants_Astronomical, only : gigaYear                       , megaParsec
    use :: Numerical_Constants_Math        , only : Pi
    use :: Numerical_Constants_Prefixes    , only : kilo
    use :: Tensors                         , only : assignment(=)                  , operator(*)   , tensorRank2Dimension3Symmetric
    use :: Vectors                         , only : Vector_Magnitude               , Vector_Product
    implicit none
    class           (nodeOperatorSatelliteTidalHeating), intent(inout), target  :: self
    type            (treeNode                         ), intent(inout)          :: node
    logical                                            , intent(inout)          :: interrupt
    procedure       (interruptTask                    ), intent(inout), pointer :: functionInterrupt
    integer                                            , intent(in   )          :: propertyType
    class           (nodeComponentSatellite           )               , pointer :: satellite
    type            (treeNode                         )               , pointer :: nodeHost
    double precision                                   , dimension(3)           :: position          , velocity
    double precision                                                            :: radius            , orbitalPeriod            , &
         &                                                                         radialFrequency   , angularFrequency
    type            (tensorRank2Dimension3Symmetric)                            :: tidalTensor       , tidalTensorPathIntegrated
    !$GLC attributes unused :: interrupt, functionInterrupt, propertyType

    if (.not.node%isSatellite()) return
    satellite                 => node     %satellite                (        )
    nodeHost                  => node     %mergesWith               (        )
    position                  =  satellite%position                 (        )
    velocity                  =  satellite%velocity                 (        )
    tidalTensorPathIntegrated =  satellite%tidalTensorPathIntegrated(        )
    radius                    =  Vector_Magnitude                   (position)
    if (radius <= 0.0d0) return ! Do not compute rates at zero radius.
    ! Calcluate tidal tensor and rate of change of integrated tidal tensor.
    tidalTensor       =Galactic_Structure_Tidal_Tensor (nodeHost,position)             
    ! Compute the orbital period.
    angularFrequency=+Vector_Magnitude(Vector_Product(position,velocity)) &
         &           /radius**2                                           &
         &           *kilo                                                &
         &           *gigaYear                                            &
         &           /megaParsec
    radialFrequency =+abs             (   Dot_Product(position,velocity)) &
         &           /radius**2                                           &
         &           *kilo                                                &
         &           *gigaYear                                            &
         &           /megaParsec
    ! Find the orbital period. We use the larger of the angular and radial frequencies to avoid numerical problems for purely
    ! radial or purely circular orbits.
    orbitalPeriod   =+2.0d0                 &
         &           *Pi                    &
         &           /max(                  &
         &                angularFrequency, &
         &                radialFrequency   &
         &               )
    ! Calculate integrated tidal tensor, and heating rates.
    call satellite%tidalTensorPathIntegratedRate(                                                   &
         &                                       +tidalTensor                                       &
         &                                       -tidalTensorPathIntegrated                         &
         &                                       /orbitalPeriod                                     &
         &                                      )
    call satellite%tidalHeatingNormalizedRate   (                                                   &
         &                                       +self%satelliteTidalHeatingRate_%heatingRate(node) &
         &                                      )
    return
  end subroutine satelliteTidalHeatingRateDifferentialEvolution
  
