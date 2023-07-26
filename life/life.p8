;*****************************************************************************
; Conway's Game of Life
; A simple Prog8 implementation by Mark J. Reed <markjreed@gmail.com>
;
; Note that the grid is limited to the size of the screen and offscreen cells
; are considered to be dead, which causes incorrect evolution for patterns
; that reach the edges.
;*****************************************************************************
%zeropage basicsafe
%import gfx2
%import syslib
%import textio

main {
  ; we set the screen mode up, so we don't have to detect the size
  const ubyte screen_mode = 0
  const ubyte width       = 80
  const ubyte height      = 60
  const ubyte footer      = height - 1

  ; some useful characters for printing
  const ubyte rvs      = $12
  const ubyte rvs_off  = $92
  const ubyte clear    = 147
  const ubyte ins      = 148

  ; offsets for updating values on screen
  const ubyte x_label   = 33
  const ubyte x_col     = 37
  const ubyte y_col     = 45
  const ubyte cells_col = 69
  const ubyte gen_col   = 19

  ; where we stick our second buffer
  const uword buffer    = $a000

  ; small optimization - keep track of where live cells are
  ; and don't bother looking outside that window when computing
  ; the next generation
  byte min_x = width as byte
  byte max_x = 0
  byte min_y = height as byte
  byte max_y = 0

  ; mouse position and stats
  ubyte screen_x
  ubyte screen_y
  uword count = 0
  uword generation = 0

  ; Tell the user how it works
  sub print_instructions() {
    ubyte count
    ubyte key
    ubyte rflag
    txt.lowercase()
    txt.plot(19,22)
    txt.print("Use the mouse to create some live cells.")
    txt.plot(11,25)
    txt.print("When happy with your pattern, press RETURN to start Life.")
    txt.plot(9,28)
    txt.print("Press RETURN again to edit the pattern, and RETURN to resume.")
    txt.plot(22,31)
    txt.print("Press Q at any time to exit program.")
    key = 0
    count = 0
    rflag = rvs
    while key == 0 {
      count = count + 1
      if count == 0 {
        rflag = rflag ^ $80
      }
      txt.plot(28,35)
      txt.chrout(rflag)
      txt.print("Press any key to begin.")
      key = cbm.GETIN()
    }
  }

  ; Set things up 
  sub init() {
    uword y
    uword x
    gfx2.screen_mode(screen_mode)
    txt.chrout(clear)
    txt.uppercase()
    txt.chrout(rvs)
    txt.print("****                         conway's game of life                          ****")
    txt.plot(0,footer)
    txt.chrout(rvs)
    txt.print("      generation:     0         x:      y:             live cells:     0       ")
    txt.plot(0,footer)
    txt.chrout(ins)
    txt.chrout(' ')
    for y in 0 to height - 1 {
      for x in 0 to width - 1 {
        @(buffer + width * y + x) = ' '
      }
    }
  }

  ; print numbers padded with spaces
  sub putbyte(ubyte value) {
    if value < 100 {
      txt.chrout(' ')
      if value < 10
        txt.chrout(' ')
      txt.print_ub(value)
    }
  }

  sub putword(uword value) {
    if value < 10000 {
      txt.chrout(' ')
      if value < 1000 {
        txt.chrout(' ')
        if value < 100 {
          txt.chrout(' ')
          if value < 10
            txt.chrout(' ')
        }
      }
    }
    txt.print_uw(value)
  }

  ; update the stats on the screen
  sub update(bool show_mouse) {
    txt.plot(x_label, footer)
    txt.chrout(rvs)
    if show_mouse {
      txt.print("x: ")
      putbyte(screen_x)
      txt.print("  y: ")
      putbyte(screen_y)
    } else {
      txt.print("               ")
    }
    txt.plot(cells_col, footer)
    putword(count)
    txt.plot(gen_col, footer)
    putword(generation)
  }

  ; called to get the initial pattern and any time the
  ; user asks to edit it mid-run
  sub get_pattern() {
    ubyte mouse_button
    uword mouse_x
    uword mouse_y
    ubyte char
    ubyte key

    cx16.mouse_config2(1)
    key = 0
    repeat {
      mouse_button = cx16.mouse_pos()
      mouse_x = cx16.r0
      mouse_y = cx16.r1
      screen_x = (mouse_x >> 3) as ubyte
      screen_y = (mouse_y >> 3) as ubyte
      update(true)
      if mouse_button {
        if screen_y > 0 and screen_y < footer {
          char = txt.getchr(screen_x, screen_y)
          if char == ' ' {
            txt.setchr(screen_x, screen_y, 'Q')
            if screen_x < min_x
              min_x = screen_x as byte
            if screen_x > max_x
              max_x = screen_x as byte
            if screen_y < min_y
              min_y = screen_y as byte
            if screen_y > max_y
              max_y = screen_y as byte
            count += 1
          } else {
            txt.setchr(screen_x, screen_y, ' ')
            count -= 1
          }
        }
        update(true)
        key = 0
        while key==0 and cx16.mouse_pos()
          and cx16.r0>>3 == screen_x and cx16.r1>>3 == screen_y {
            key = cbm.GETIN() as ubyte
            if key break
        }
      }
      if key == 0 key = cbm.GETIN() as ubyte
      when key {
        '\r' -> break
        'q'  -> { 
          txt.print("quit")
          sys.exit(1)
        }
      }
    }
    cx16.mouse_config2(0)
  }

  ; compute the next generation
  sub next_generation() {
    ubyte y
    ubyte x
    byte dy
    byte dx
    byte ny
    byte nx
    ubyte neighbors
    bool alive
    ubyte key

    if min_y < 2 { min_y=2 }
    if max_y > footer-2 { max_y=footer-2 }

    for y in min_y - 1 as ubyte to max_y + 1 as ubyte {
        if min_x < 1 { min_x=1 }
        if max_x > width-2 { max_x=width-2 }
        for x in min_x - 1 as ubyte to max_x + 1 as ubyte {
            alive = (txt.getchr(x,y) != ' ')
            neighbors = 0
            for dy in -1 to 1 {
              ny = (y as byte) + dy
              if ny >= 1 and ny < footer {
                for dx in -1 to 1 {
                  if 0!=dx or 0!= dy  {
                    nx = (x as byte) + dx
                    if 0 <= nx and nx < width {
                      if txt.getchr(nx as ubyte, ny as ubyte) != ' '
                        neighbors += 1
                    }
                  }
                }
              }
            }
            uword bufadr = buffer + width * (y as uword) + (x as uword)
            if neighbors == 3 or (alive and neighbors==2) {
              @(bufadr) = 'Q'
              if alive==0 {
                count += 1
              }
              if x < min_x 
                min_x = x as byte
              if x > max_x
                max_x = x as byte
              if y < min_y 
                min_y = y as byte
              if y > max_y
                max_y = y as byte
            } else {
              @(bufadr) = ' '
              if alive {
                count -= 1
              }
            }
      }
    }
    copy_buffer()
    generation = generation + 1
    update(false)
    key = 0
  }

  ; set up VERA for the bulk copy from the second buffer
  ; to the visible screen
  asmsub setup_vera() clobbers(A,X,Y) {
    %asm {{
      ; set up data channel 0
      lda cx16.VERA_CTRL
      and #$fe
      sta cx16.VERA_CTRL

      ; auto-inc=2, high bit=1
      lda #$21
      sta cx16.VERA_ADDR_H
    }}
  }

  ; copy the grid from the second buffer to the visible screen
  sub copy_buffer() {
    %asm{{ sei }}
    ubyte x
    ubyte y
    ubyte code
    setup_vera()
    uword rowaddr
    min_y = footer
    max_y = 0
    min_x = width
    max_x = 0
    for y in 1 to footer-1 {
      rowaddr = buffer + width * (y as uword)
      cx16.VERA_ADDR_M = $b0 + y
      cx16.VERA_ADDR_L = $00
      for x in 0 to width-1 {
        code = @(rowaddr + (x as uword))
        if code != ' ' {
          if x < min_x 
            min_x = x as byte
          if x > max_x
            max_x = x as byte
          if y < min_y 
            min_y = y as byte
          if y > max_y
            max_y = y as byte
        }
        cx16.VERA_DATA0 = code
      }
    }
    %asm {{
      cli
    }}
  }

  ; here we go
  sub start() {
    print_instructions()
    init()
    get_pattern()
    update(false)
    ubyte char
    while count > 0 {
      char = cbm.GETIN() as ubyte
      when char {
        '\r' -> get_pattern()
        'q'  -> break
      }
      next_generation()
    }
  }
}
