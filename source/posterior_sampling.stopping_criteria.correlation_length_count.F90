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

  !% Implementation of a posterior sampling stopping class which stops after a given number of correlation legnths.

  use Posterior_Sampling_Convergence
  
  !# <posteriorSampleStoppingCriterion name="posteriorSampleStoppingCriterionCorrelationLength" defaultThreadPrivate="yes">
  !#  <description>A posterior sampling stopping class which stops after a given number of correlation lengths.</description>
  !# </posteriorSampleStoppingCriterion>
  type, extends(posteriorSampleStoppingCriterionClass) :: posteriorSampleStoppingCriterionCorrelationLength
     !% Implementation of a posterior sampling convergence class which stops after a given number of correlation lengths.
     private
     class  (posteriorSampleConvergenceClass), pointer :: posteriorSampleConvergence_
     integer                                           :: stopAfterCount
   contains
     final     ::         correlationLengthDestructor
     procedure :: stop => correlationLengthStop
  end type posteriorSampleStoppingCriterionCorrelationLength

  interface posteriorSampleStoppingCriterionCorrelationLength
     !% Constructors for the {\normalfont \ttfamily correlationLength} posterior sampling stopping criterion class.
     module procedure correlationLengthConstructorParameters
     module procedure correlationLengthConstructorInternal
  end interface posteriorSampleStoppingCriterionCorrelationLength

contains

  function correlationLengthConstructorParameters(parameters) result(self)
    !% Constructor for the {\normalfont \ttfamily correlationLength} posterior sampling stopping class which builds the object from a parameter set.
    use Input_Parameters
    implicit none
    type   (posteriorSampleStoppingCriterionCorrelationLength)                :: self
    type   (inputParameters                                  ), intent(inout) :: parameters
    class  (posteriorSampleConvergenceClass                  ), pointer       :: posteriorSampleConvergence_
    integer                                                                   :: stopAfterCount

    !# <inputParameter>
    !#   <name>stopAfterCount</name>
    !#   <cardinality>1</cardinality>
    !#   <description>The number of correlation lengths to continue after convergence before stopping.</description>
    !#   <source>parameters</source>
    !#   <type>real</type>
    !# </inputParameter>
    !# <objectBuilder class="posteriorSampleConvergence" name="posteriorSampleConvergence_" source="parameters"/>
    self=posteriorSampleStoppingCriterionCorrelationLength(stopAfterCount,posteriorSampleConvergence_)
    !# <inputParametersValidate source="parameters"/>
   return
  end function correlationLengthConstructorParameters

  function correlationLengthConstructorInternal(stopAfterCount,posteriorSampleConvergence_) result(self)
    !% Internal constructor for the {\normalfont \ttfamily correlationLength} posterior sampling stopping class.
    use Input_Parameters
    implicit none
    type   (posteriorSampleStoppingCriterionCorrelationLength)                        :: self
    integer                                                   , intent(in   )         :: stopAfterCount
    class  (posteriorSampleConvergenceClass                  ), intent(in   ), target :: posteriorSampleConvergence_
    !# <constructorAssign variables="stopAfterCount, *posteriorSampleConvergence_"/>
    
    return
  end function correlationLengthConstructorInternal

  subroutine correlationLengthDestructor(self)
    !% Destructor for the {\normalfont \ttfamily correlationLength} posterior sampling stopping class.
    implicit none
    type(posteriorSampleStoppingCriterionCorrelationLength), intent(inout) :: self

    !# <objectDestructor name="self%posteriorSampleConvergence_"/>
    return
  end subroutine correlationLengthDestructor

  logical function correlationLengthStop(self,simulationState)
    !% Returns true if the posterior sampling should stop.
    use Galacticus_Error
    implicit none
    class(posteriorSampleStoppingCriterionCorrelationLength), intent(inout) :: self
    class(posteriorSampleStateClass                        ), intent(inout) :: simulationState


    select type (simulationState)
       class is (posteriorSampleStateCorrelation)
       correlationLengthStop=                                                      &
            &   self%posteriorSampleConvergence_%isConverged                    () &
            & .and.                                                                &
            &       simulationState             %postConvergenceCorrelationCount() &
            &  >                                                                   &
            &   self                            %stopAfterCount
       class default
       correlationLengthStop=.false.
       call Galacticus_Error_Report('state object does not support correlation length count'//{introspection:location})
    end select
    return
  end function correlationLengthStop