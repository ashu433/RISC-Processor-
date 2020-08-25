module IITB_RISC_tb;

  reg clk1, clk2;
  integer k;

  IITB_RISC pipeline (clk1, clk2);

  initial
     begin
	clk1 = 0; clk2 = 0;
	repeat (20)		//Generating two phase clock
	  begin
	    #5 clk1 = 1;  #5 clk1 = 0;
	    #5 clk2 = 1;  #5 clk2 = 0;
	  end
      end	    

  initial
     begin
	//for (k=0; k<7; k++)
	 // pipeline.Reg[0] = 16'hFFFF;
	 // pipeline.Reg[1] = 16'h7FFF;
	for (k=0; k<8; k++)
	  pipeline.Reg[k] = k+10;

	pipeline.Mem[0] = 16'b0000000001010000; //ADD R0 R1 R2
	pipeline.Mem[1] = 16'b1001000010000000; //JLR R0 R2 000000
	//pipeline.Mem[1] = 16'b1100110010010000; //BEQ R6 R2 010000(16)
	//pipeline.Mem[1] = 16'b0101101010010000; //SW R5 R2 100000
	//pipeline.Mem[1] = 16'b0001010100000111; //ADI R2 R4 7
	//pipeline.Mem[1] = 16'b0100000010010000; //LW R0 R2 10000
	//pipeline.Mem[1] = 16'b0000011001101000; //ADD R3 R1 R5
	pipeline.Mem[2] = 16'b0000010100110000; //ADD R2 R4 R6
	pipeline.Mem[3] = 16'b0000110100111000; //ADD R6 R4 R7
	pipeline.Mem[4] = 16'b0000011100000000; //ADD R3 R4 R0

	//pipeline.Mem[3] = 16'b0000001100111000; //ADD R1 R4 R7
	
//	pipeline.Mem[1] = 16'b1001000001000000; //JLR R0 R1 000000
//	pipeline.Mem[2] = 16'b0000000001010000; //ADD R0 R1 R2
//	pipeline.Mem[3] = 16'b0000000001010000; //ADD R0 R1 R2
//	pipeline.Mem[1] = 16'b1000000000010000; //JAL R0 000010000(16) 
	//pipeline.Mem[1] = 16'b1100000010010000; //BEQ R0 R2 010000(16)
//	pipeline.Mem[2] = 16'b0000011100101000; //ADD R3 R4 R5
	//pipeline.Mem[1] = 16'b0001000100000111; //ADI R0 R4 7
	//pipeline.Mem[2] = 16'b0000011100101010; //ADC R3 R4 R5
	//pipeline.Mem[3] = 16'b0000011100101001; //ADZ R3 R4 R5
	//pipeline.Mem[1] = 16'b0011101111100000; //LHI R5 111111111
	//pipeline.Mem[1] = 16'b0100000101010000; //LW R0 R5 100000
       	//pipeline.Mem[1] = 16'b0101000101010000; //SW R0 R5 100000
        //pipeline.Mem[1] = 16'b0110000011111111; //LM R0 R5 100000
		
//        for (k=0; k<20; k++)
//	  pipeline.Mem[k] = k+2000;

	pipeline.Mem[26] = 5000; //LHI R5 111111111
	pipeline.Mem[27] = 5001; //LHI R5 111111111
	
	pipeline.HALTED = 0;
	pipeline.PC = 0;
	pipeline.TAKEN_BRANCH = 0;
	pipeline.Carry = 0;
	pipeline.Zero = 0;

	#78
	for (k=0; k<8; k++)
	  $display ("R%1d - %2d", k, pipeline.Reg[k]);
        for (k=0; k<50; k++)
	  $display ("M%1d - %2d", k, pipeline.Mem[k]);

     end

  initial 
     begin
	$dumpfile ("pipeline.vcd");
	$dumpvars (0, IITB_RISC_tb);
	#300 $finish;
     end

endmodule 

