!! Copyright 2009, 2010, 2011, 2012, 2013, 2014, 2015, 2016, 2017, 2018
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

  !% Implementation of a merger tree halo mass function sampling class in which the sampling rate is given by a power-law in halo mass.

  !# <mergerTreeBuildMassDistribution name="mergerTreeBuildMassDistributionPowerLaw" defaultThreadPrivate="yes">
  !#  <description>A merger tree halo mass function sampling class in which the sampling rate is given by a power-law in halo mass.</description>
  !# </mergerTreeBuildMassDistribution>
  type, extends(mergerTreeBuildMassDistributionClass) :: mergerTreeBuildMassDistributionPowerLaw
     !% Implementation of merger tree halo mass function sampling class in which the sampling rate is given by a power-law in halo mass.
     private
     double precision :: exponent
   contains
     procedure :: sample => powerLawSample
  end type mergerTreeBuildMassDistributionPowerLaw

  interface mergerTreeBuildMassDistributionPowerLaw
     !% Constructors for the {\normalfont \ttfamily powerLaw} merger tree halo mass function sampling class.
     module procedure powerLawConstructorParameters
     module procedure powerLawConstructorInternal
  end interface mergerTreeBuildMassDistributionPowerLaw

contains

  function powerLawConstructorParameters(parameters) result(self)
    !% Constructor for the {\normalfont \ttfamily powerLaw} merger tree halo mass function sampling class which builds the object from a parameter set.
    use Input_Parameters
    implicit none
    type            (mergerTreeBuildMassDistributionPowerLaw)                :: self
    type            (inputParameters                           ), intent(inout) :: parameters
    double precision                                                            :: exponent

    !# <inputParameter>
    !#   <name>exponent</name>
    !#   <cardinality>1</cardinality>
    !#   <defaultValue>1.0d0</defaultValue>
    !#   <description>Halo masses will be (pseudo-)uniformly distributed in $[\log(M)]^{1/(1+\alpha)}$ where $\alpha=${\normalfont \ttfamily exponent}.</description>
    !#   <source>parameters</source>
    !#   <type>real</type>
    !# </inputParameter>
    self=mergerTreeBuildMassDistributionPowerLaw(exponent)
    !# <inputParametersValidate source="parameters"/>
    return
  end function powerLawConstructorParameters

  function powerLawConstructorInternal(exponent) result(self)
    !% Internal constructor for the {\normalfont \ttfamily powerLaw} merger tree halo mass function sampling class.
    implicit none
    type            (mergerTreeBuildMassDistributionPowerLaw)                :: self
    double precision                                            , intent(in   ) :: exponent
    !# <constructorAssign variables="exponent"/>
    
    return
  end function powerLawConstructorInternal

  double precision function powerLawSample(self,mass,time,massMinimum,massMaximum)
    !% Computes the halo mass function sampling rate using a volume-limited sampling.
    implicit none
    class           (mergerTreeBuildMassDistributionPowerLaw), intent(inout) :: self
    double precision                                            , intent(in   ) :: mass       , massMaximum, &
         &                                                                         massMinimum, time
    !GCC$ attributes unused :: time

    ! Sampling rate is simply a power-law in the logarithm of halo mass.
    if (mass <= massMinimum .or. mass > massMaximum) then
       powerLawSample=0.0d0
    else
       powerLawSample=+log10(              &
            &                +mass         &
            &                /massMinimum  &
            &               )              &
            &          **(                 &
            &             -  self%exponent &
            &             /(               &
            &               +1.0d0         &
            &               +self%exponent &
            &              )               &
            &            )
    end if
    return
  end function powerLawSample