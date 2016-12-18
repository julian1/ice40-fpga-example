
// OK, be nice to separate out the module...


module blinkmodule (
  input  clk,
  output LED
);
  reg [31:0] counter2 = 0;

  // we need to control this more carefully
  // being able to control several input is a good thing...
  // as well as ref
  // might want to control the switching - just with spi commands...
  // to test...

  always@(posedge clk) begin
    counter2 <= counter2 + 1;
  end
  assign {LED} = counter2 >> 22;
endmodule



// works!

module SPI_slave(
  input clk,
  input SCK,
  input SSEL,
  input MOSI,
  output MISO,

  output led1,
  output led2,
  output led3,

  output m_reset,
  output m_in,
  output m_ref
);

  // clk domain crossing - this works by storing the last two sck states, and then compare them to
  // to determine if it's rising or falling.

  // sync SCK to the FPGA clock using a 3-bits shift register
  reg [2:0] SCKr;  always @(posedge clk) SCKr <= {SCKr[1:0], SCK};
  wire SCK_risingedge = (SCKr[2:1]==2'b01);  // now we can detect SCK rising edges
  wire SCK_fallingedge = (SCKr[2:1]==2'b10);  // and falling edges

  // same thing for SSEL
  reg [2:0] SSELr;  always @(posedge clk) SSELr <= {SSELr[1:0], SSEL};
  wire SSEL_active = ~SSELr[1];  // SSEL is active low
  wire SSEL_startmessage = (SSELr[2:1]==2'b10);  // message starts at falling edge
  wire SSEL_endmessage = (SSELr[2:1]==2'b01);  // message stops at rising edge

  // and for MOSI
  reg [1:0] MOSIr;  always @(posedge clk) MOSIr <= {MOSIr[0], MOSI};
  wire MOSI_data = MOSIr[1];


  /////////////////////////////////////
  // read in 8bit message
  // IT would be easy to make this longer
  // we handle SPI in 8-bits format, so we need a 3 bits counter to count the bits as they come in
  reg [2:0] bitcnt;
  reg byte_received;  // high when a byte has been received
  reg [7:0] byte_data_received;

  always @(posedge clk)
  begin
    if(~SSEL_active)
      bitcnt <= 3'b000;
    else
    if(SCK_risingedge)
    begin
      bitcnt <= bitcnt + 3'b001;

      // implement a shift-left register (since we receive the data MSB first)
      byte_data_received <= {byte_data_received[6:0], MOSI_data};
    end
  end

  always @(posedge clk)
    byte_received <= SSEL_active && SCK_risingedge && (bitcnt==3'b111);



  //////////////////////////////////////////////
  // global clock...
  reg [31:0] count = 0;



  //////////////////////////////////////////////
  // decode messages and process

  // we could set the 5v power separatee
  reg init_ = 0;            // https://github.com/cliffordwolf/yosys/issues/103
                            // init_ialized to zero
                            // note - reset can lead to lower f(max)..
                            // 1MHz in this case,

  // dg444 is switched either ref or in
  assign m_ref = !m_in;

  always @(posedge clk)
    if(!init_)
    begin
      init_ <= 1;
      m_reset <= 0;
      m_in <= 0;   // assert m_in
    end
    else if(byte_received && byte_data_received == 8'hcc)
    begin
        // if message 0xcc to reset
        count <= 0;
    end
    else
    begin
        // otherwise always increment clock
        count <= count + 1;

        if(byte_received)
        begin
          // reset
          if(byte_data_received == 8'hca)         // integrate
            m_reset <= 1'b1;
          else if (byte_data_received == 8'hcb)   // short cap/reset
            m_reset <= 1'b0;

          else if (byte_data_received == 8'hcd)   // 0V
            m_in <= 1'b1;
          else if (byte_data_received == 8'hce)   // 5V
            m_in <= 1'b0;
        end
    end

  // led follows m_reset
  assign led1 = m_reset;
  assign led2 = m_in;
  assign led3 = m_ref;


  //////////////////////////////////////////////
  // write count as output
  reg [31:0] byte_data_sent;

  always @(posedge clk)
  if(SSEL_active)
  begin
    if(SSEL_startmessage)
      byte_data_sent <= count;
    else
    if(SCK_fallingedge)
    begin
        byte_data_sent <= {byte_data_sent[30:0], 1'b0};
    end
  end

  assign MISO = byte_data_sent[31];  // send MSB first
  // we assume that there is only one slave on the SPI bus
  // so we don't bother with a tri-state buffer for MISO
  // otherwise we would need to tri-state MISO when SSEL is inactive


endmodule



module top (
  input  clk,

  output led1,
  output led2,
  output led3,
  output led4,
  output led5,

  // module SPI_slave(clk, SCK, SSEL, MOSI, MISO,  LED, a);
  input sck,
  input ssel,
  input mosi,
  output miso,

  output m_vl,
  output m_ref,
  output m_in,
  output m_reset
);

  blinkmodule #()
  blinkmodule
    (
    .clk(clk),
    .LED(led1)
  );


  SPI_slave #()
  SPI_slave
    (
    .clk(clk),
    .SCK(sck),
    .MOSI(mosi),
    .MISO(miso),
    .SSEL(ssel),

    .led1(led2),
    .led2(led3),
    .led3(led4),

    .m_reset(m_reset),
    .m_in(m_in),
    .m_ref(m_ref)
  );

  // need data structure?

  // set the logic voltage reference, VL of dg444
  assign m_vl = 1'b1;

endmodule


