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

!% Contains a module which performs tasks associated with ``halo formation'' events.

module Events_Halo_Formation
  !% Performs tasks associated with ``halo formation'' events.
  implicit none
  private
  public :: Event_Halo_Formation

contains

  subroutine Event_Halo_Formation(node)
    !% Perform tasks associated with a ``halo formation'' event in {\normalfont \ttfamily node}.
    use :: Galacticus_Nodes, only : treeNode
    !# <include directive="haloFormationTask" type="moduleUse">
    include 'events.halo_formation.moduleUse.inc'
    !# </include>
    implicit none
    type(treeNode), intent(inout) :: node

    ! Allow arbitrary routines to perform tasks.
    !# <include directive="haloFormationTask" type="functionCall" functionType="void">
    !#  <functionArgs>node</functionArgs>
    include 'events.halo_formation.inc'
    !# </include>

    return
  end subroutine Event_Halo_Formation

end module Events_Halo_Formation
