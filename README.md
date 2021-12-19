
OBS Studio Lua Scripts
======================

About
-----

This is a small collection of [Lua](http://www.lua.org/)
scripts for automating certain tasks and extending the
functionality in the video/audio stream mixing software [OBS
Studio](https://obsproject.com/).

The individual scripts are:

- [clone-template-scene.lua](clone-template-scene.lua):<br/>
  Clone an entire source scene (template), by creating a target scene
  (clone) and copying all corresponding sources, including their
  filters, transforms, etc. This is usually used for creating scenes,
  based on the same set of template scenes, during event preparation.

- [refresh-browser-sources.lua](refresh-browser-sources.lua):<br/>
  Refresh all <i>Browser Source</i> sources. This is usally used to
  refresh Browser Source based Head-Up-Display (HUD), Lower Thirds or
  Banner widgets during event preparation.

- [keyboard-event-filter.lua](keyboard-event-filter.lua):<br/>
  Define a Keyboard Event filter for sources. This is intended to
  map OBS Studio global hotkeys onto keyboard events for Browser
  Source sources. This is usually used to map global hotkeys (or even
  attached StreamDeck keys) onto keystrokes for Browser Source based
  Head-Up-Display (HUD), Lower Thirds or Banner widgets during event
  production.

- [production-information.lua](production-information.lua):<br/>
  Updates Text/GDI+ sources with the current Preview and Program scene
  information, the current wallclock time and the current on-air
  duration time in order to broadcast this information during production
  to the involved people. This is usually used for broadcasting central
  information during event production.

- [source-one-of-many.lua](source-one-of-many.lua):<br/>
  Toggle between one of many sources visible in a scene/group. If
  a source is made visible in a scene/group, all other sources are
  automatically made non-visible. The currently already visible source
  is made visible immediately again, if it is accidentally requested
  to be made non-visible. So, at each time, only one source is visible
  within the scene/group.

Installation
------------

1. Clone this repository:<br/>
   `git clone https://github.com/rse/obs-scripts`

2. Add the individual scripts to OBS Studio with<br/>
   **Tools** &rarr; **Scripts** &rarr; **+** (Add Script)

License
-------

Copyright &copy; 2021 Dr. Ralf S. Engelschall (http://engelschall.com/)

Permission is hereby granted, free of charge, to any person obtaining
a copy of this software and associated documentation files (the
"Software"), to deal in the Software without restriction, including
without limitation the rights to use, copy, modify, merge, publish,
distribute, sublicense, and/or sell copies of the Software, and to
permit persons to whom the Software is furnished to do so, subject to
the following conditions:

The above copyright notice and this permission notice shall be included
in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY
CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT,
TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE
SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

