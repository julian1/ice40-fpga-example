
// from https://github.com/cliffordwolf/icestorm/tree/master/examples/icestick

// example.v


// HANG on how does register shadowing work???

// have separate modules for an 8 bit mux.
// versus a 16 bit reg value
// versus propagating.


module blinker    (
  input clk,
  output led1,
  output led2

);

  localparam BITS = 5;
  // localparam LOG2DELAY = 21;
  localparam LOG2DELAY = 19;

  reg [BITS+LOG2DELAY-1:0] counter = 0;
  reg [BITS-1:0] outcnt;

  always@(posedge clk) begin
    counter <= counter + 1;
    outcnt <= counter >> LOG2DELAY;
  end

  // assign {led1} = counter2 >> 22;
  // assign { led1, led2, LED3, LED4, LED5 } = outcnt ^ (outcnt >> 1);
  assign {  led1, led2 } = outcnt ^ (outcnt >> 1);
endmodule


// ok. lets try to use the special flag.


/*
    we just want a register bank....
*/


module mylatch   #(parameter MSB=16)   (
  input  clk,
  input  cs,
  input  special,
  input  d,   // sdi

  // latched val, rename
  output reg [8-1:0] reg_led,
  output reg [8-1:0] reg_mux
);

  // if the clk count is wrong. it will make a big mess.
  // would be much better if could validate.

  reg [MSB-1:0] tmp;

  always @ (negedge clk)
  begin
    if (!cs && !special)         // chip select asserted.
    // if (!cs )         // chip select asserted.
      tmp <= {tmp[MSB-2:0], d};
    // else
    //  tmp <= tmp;
  end
  /*
    RIGHT. it doesn't like having both a negedge and posedge...
  */


  /* 
  // these don't work...
  assign address = tmp[ MSB-1:8 ];
  assign value   = tmp[ 8 - 1: 0 ];
  */

  always @ (posedge cs)
  begin

    if(!special)    // special asserted

      case (tmp[ MSB-1:8 ])  // high byte for reg, lo byte for val.

        // leds
        7 :   reg_led = tmp[ 8 - 1: 0 ];

        // mux
        8 :   reg_mux = tmp[ 8 - 1: 0 ];

      endcase


  end
endmodule




module mymux    (

  input wire [8-1:0] reg_mux,     // inputs are wires. cannot be reg.

  input  cs,
  output adc03_cs,

);
  always @ (reg_mux )     // eg. whenever reg_mux changes we update ... i think.
    begin

      case (reg_mux )
        1 :
        begin
          adc03_cs = cs;
        end

        default  :
        begin
          adc03_cs = 1;   // deassert
        end
      endcase
    end
endmodule


// OK. we only want to latch the value in, on correct clock transition count.


/*
  EXTREME
    - we ought should be able to do miso / sdo - easily - its the same as the other peripheral wires going to dac,adc etc.
    - there may be an internal creset?
*/

module top (
  input  XTALCLK,

  // leds
  output LED1,
  output LED2,

  // spi
  input CLK,
  input CS,
  input MOSI,
  input SPECIAL
  // output b
);
  // should be able to assign extra stuff here.
  //



  ////////////////////////////////////
  // sayss its empty????
  wire [8-1:0] reg_mux;
  wire [8-1:0] reg_led;

  assign {LED1, LED2} = reg_led;

  mylatch #( 16 )   // register bank
  mylatch
    (
    .clk(CLK),
    .cs(CS),
    .special(SPECIAL),
    .d(MOSI),
    .reg_led(reg_led),
    .reg_mux(reg_mux)
  );





  mymux #( )
  mymux
  (
    . reg_mux(reg_mux),
    . cs(CS),
    . adc03_cs(ADC03_CS)
  );


  // want to swapt the led order.
  // assign LED1 = MOSI;
  // assign LED1 = MOSI;
  // assign LED1 = SPECIAL;

/*
  blinker #(  )
  blinker
    (
    .clk(XTALCLK),
    .led1(LED1),
    .led2(LED2)
  );
*/




endmodule


