module IITB_RISC (clk1,clk2);

  input clk1, clk2; 	//Two-phase clock 
  
  reg [15:0] PC, IF_ID_IR, IF_ID_NPC;
  reg [15:0] ID_RR_IR, ID_RR_NPC,ID_RR_Imm9, RR_EX_A, RR_EX_B, RR_EX_Imm9, RR_EX_IR, 
    	     RR_EX_NPC,ID_RR_Imm6,RR_EX_Imm6;
  reg [2:0]  ID_RR_type,RR_EX_type, EX_MEM_type, MEM_WB_type;
  reg [15:0] EX_MEM_IR,MEM_WB_IR, EX_MEM_A,EX_MEM_Imm9,MEM_WB_A,MEM_WB_LMD;
  reg [16:0] EX_MEM_ALUout, MEM_WB_ALUout;
  reg [16:0] R0_M,R1_M,R2_M,R3_M,R4_M,R5_M,R6_M,R7_M;
  reg        EX_MEM_cond,Zero,Carry;
				
  reg [15:0] Reg [0:7];		 // 7 General purpose Registers		
  reg [15:0] Mem [0:1023];       // Memory

  parameter Addition=4'b0000, ADI=4'b0001, Nand=4'b0010, LHI=4'b0011, LW=4'b0100, 
            SW=4'b0101, LM=4'b0110, SM=4'b0111, BEQ=4'b1100, JAL=4'b1000, JLR=4'b1001,
	    ADD_NDU=3'b000, ADC_NDC=3'b010, ADZ_NDZ=3'b001;
  
  parameter RR_ALU=5'b00000, RM_ALU=5'b00001, LOAD=5'b00010, STORE=5'b00011, 
  	    BRANCH=5'b00100, JUMP=5'b00101, HALT=5'b00111;

  reg HALTED;  		        //Set after HLT instruction is completed in wb stage
  reg TAKEN_BRANCH;             //Required to disable instructions after branch
		
//=========================== IF Stage ==================================//

always @(posedge clk1)
   if (HALTED==0)
   begin
     if (((EX_MEM_IR[15:12] == BEQ) && (EX_MEM_cond == 1)) ||
         ((EX_MEM_IR[15:12] == JAL)) ||
         ((EX_MEM_IR[15:12] == JLR)))
        begin
          IF_ID_IR     <= Mem[EX_MEM_ALUout];
	  TAKEN_BRANCH <= 1'b1;
          IF_ID_NPC    <= EX_MEM_ALUout + 1;
	  PC           <= EX_MEM_ALUout + 1;
	end
     else
       begin 
	  IF_ID_IR     <= Mem[PC];
	  IF_ID_NPC    <= PC + 1;
	  PC           <= PC + 1;
	end
   end

//=========================== ID Stage ==================================//

always @(posedge clk2)
   if (HALTED==0)
   begin
    ID_RR_NPC <= IF_ID_NPC;
    ID_RR_IR  <= IF_ID_IR;
    ID_RR_Imm9 <= {{7{IF_ID_IR[8]}}, {IF_ID_IR[8:0]}};
    ID_RR_Imm6 <= {{10{IF_ID_IR[5]}}, {IF_ID_IR[5:0]}};
       case (IF_ID_IR[15:12])
  	  Addition, Nand : ID_RR_type <= RR_ALU;
	  ADI, LHI	 : ID_RR_type <= RM_ALU;
 	  LW, LM	 : ID_RR_type <= LOAD;
	  SW, SM	 : ID_RR_type <= STORE;
	  BEQ		 : ID_RR_type <= BRANCH;
	  JAL,JLR	 : ID_RR_type <= JUMP;
//	  HLT		 : ID_RR_type <= HALT;
	  default	 : ID_RR_type <= HALT;   //invalid opcode

       endcase  
   end

//=========================== RR Stage ==================================//

always @(posedge clk1)
   if (HALTED==0)
   begin
     
     RR_EX_NPC  <= ID_RR_NPC;
     RR_EX_IR   <= ID_RR_IR;
     RR_EX_Imm6  <= ID_RR_Imm6;
     RR_EX_Imm9  <= ID_RR_Imm9;
     RR_EX_type <= ID_RR_type;
     if ((ID_RR_IR[15:12] == Addition) || (ID_RR_IR[15:12] == Nand) || (ID_RR_IR[15:12] == SW) || (ID_RR_IR[15:12] == BEQ)) //Dependencies for Add/Nand/SW i.e. forwarding
     begin
        if (ID_RR_IR[11:9]==RR_EX_IR[5:3])   
	  begin
	  RR_EX_A   <= EX_MEM_ALUout;
	  RR_EX_B   <= Reg[ID_RR_IR[8:6]];
	  end
	else if (ID_RR_IR[8:6]==RR_EX_IR[5:3])
	  begin
	  RR_EX_B   <= EX_MEM_ALUout;
	  RR_EX_A   <= Reg[ID_RR_IR[11:9]];
	  end
	else
	  begin
	  RR_EX_A    <= Reg[ID_RR_IR[11:9]];		//RA
    	  RR_EX_B    <= Reg[ID_RR_IR[8:6]];		//RB
	  end
     end

 
        if (ID_RR_IR[15:12] == ADI)  //Dependencies for ADI i.e. forwarding
	  begin
            if (ID_RR_IR[11:9]==RR_EX_IR[5:3])   
	     RR_EX_A   <= EX_MEM_ALUout;	    
	  end

	if ((ID_RR_IR[15:12] == LW) || (ID_RR_IR[15:12] == JLR))  //Dependencies for LW i.e. forwarding
	  begin
            if (ID_RR_IR[8:6]==RR_EX_IR[5:3])   
	     RR_EX_B   <= EX_MEM_ALUout;	    
	  end


	
     
   end

//=========================== EX Stage ==================================//

always @(posedge clk2)
   if (HALTED==0)
   begin
     EX_MEM_type   <=  RR_EX_type;
     EX_MEM_IR	   <=  RR_EX_IR;
     EX_MEM_Imm9   <=  RR_EX_Imm9;
     TAKEN_BRANCH  <=  0;
	
	if ((RR_EX_IR[15:12]==Addition) && (RR_EX_IR[2:0]==ADD_NDU))
//	  begin
		EX_MEM_ALUout <= RR_EX_A + RR_EX_B;
//		if ((EX_MEM_ALUout == 17'b00000000000000000))
//		   begin		
//			Zero = 1;
//		   end
//	       else if (EX_MEM_ALUout[16]==1)
//		   begin			
//			Carry = 1;
//		else
//		     Zero = 0;
//		   end
	//	else 
	//		Carry == 0;	
//	  end

	else if ((RR_EX_IR[15:12]==Addition) && (RR_EX_IR[2:0]==ADC_NDC) && (Carry==1))
//	   begin
		EX_MEM_ALUout <= RR_EX_A + RR_EX_B;
//		if (EX_MEM_ALUout == 17'b0000000000000000)
//		   begin			
//			Zero = 1;
//		   end
//		else if (EX_MEM_ALUout[16]==1)
//		   begin			
//			Carry = 1;
//		   end		
//	   end

	else if ((RR_EX_IR[15:12]==Addition) && (RR_EX_IR[2:0]==ADZ_NDZ) && (Zero==1))
//	  begin
		EX_MEM_ALUout <= RR_EX_A + RR_EX_B;
//		if (EX_MEM_ALUout == 17'b0000000000000000)
//		   begin		
// 			Zero = 1;
//		   end
//		else if (EX_MEM_ALUout[16]==1)
//		   begin			
//			Carry = 1;
//		   end		
//	  end

	else if ((RR_EX_IR[15:12]==Nand) && (RR_EX_IR[2:0]==ADD_NDU))
//	  begin
		EX_MEM_ALUout <= RR_EX_A ~& RR_EX_B;
//		if (EX_MEM_ALUout == 17'b0000000000000000)
//		   begin			
//			Zero = 1;
//	       	   end
//		else 
//			Zero = 0;
//	  end	

	else if ((RR_EX_IR[15:12]==Nand) && (RR_EX_IR[2:0]==ADC_NDC) && (Carry==1))
//	  begin
		EX_MEM_ALUout <= RR_EX_A ~& RR_EX_B;
//		if (EX_MEM_ALUout == 17'b0000000000000000)
//		   begin
//			Zero = 1;
//		   end
//	  end	

	else if ((RR_EX_IR[15:12]==Nand) && (RR_EX_IR[2:0]==ADZ_NDZ) && (Zero==1))
//	  begin
		EX_MEM_ALUout <= RR_EX_A ~& RR_EX_B;
//		if (EX_MEM_ALUout == 17'b0000000000000000)
//		  begin
//			Zero = 1;
//		  end
//	  end

	else if (RR_EX_IR[15:12]==ADI)
//	   begin
		EX_MEM_ALUout <= RR_EX_A + RR_EX_Imm6;		//ALUout has the value to be stored in RB
//		if (EX_MEM_ALUout == 17'b0000000000000000)
//		  begin
//			Zero = 1;
//		  end
//		else if (EX_MEM_ALUout[16]==1)
//		  begin
//			Carry = 1;
//		  end
//	end
	
	else if (RR_EX_IR[15:12]==LW)
//	   begin
		EX_MEM_ALUout <= RR_EX_B+ RR_EX_Imm6;  //Memory adress. Value to be stored in RA
		//EX_MEM_A      <= RR_EX_A;
//		if (EX_MEM_ALUout == 17'b0000000000000000)
//		   begin
//			Zero = 1;
//		   end
//	end

	else if (RR_EX_IR[15:12]==LHI)
//	   begin
		EX_MEM_A   <=  {RR_EX_Imm9[8:0],7'b0000000};  //To be stored in RA
		             
//	   end

	else if (RR_EX_IR[15:12]==SW)
	   begin
		EX_MEM_ALUout <= RR_EX_B+ RR_EX_Imm6;    //Memory adress. RA value to be stored here
		EX_MEM_A      <= RR_EX_A;
	   end
	
	else if (RR_EX_IR[15:12]==BEQ)
	   begin
		EX_MEM_ALUout  <=  RR_EX_NPC + RR_EX_Imm6;
		EX_MEM_cond    <=  ((RR_EX_A-RR_EX_B) == 0);
	   end	

	else if (RR_EX_IR[15:12]==JAL)
	   begin
		EX_MEM_ALUout  <=  RR_EX_NPC + RR_EX_Imm9;
		EX_MEM_A       <=  RR_EX_NPC;		//To be stored in RA
	   end	

	else if (RR_EX_IR[15:12]==JLR)
	   begin
		EX_MEM_ALUout  <=  RR_EX_B + 16'b0000000000000000;  //branch to this adress
		EX_MEM_A       <=  RR_EX_NPC;
	   end

	else if (RR_EX_IR[15:12]==LM)
	   begin
		EX_MEM_ALUout  <=  RR_EX_A + 16'b0000000000000000;
		EX_MEM_Imm9    <=  RR_EX_Imm9;
	   end

	else if (RR_EX_IR[15:12]==SM)
	   begin
		EX_MEM_ALUout  <=  RR_EX_A + 16'b0000000000000000;
		EX_MEM_Imm9    <=  RR_EX_Imm9;
	   end


   end

//=========================== MEM Stage ==================================//

always @(posedge clk1)
 //  if ((HALTED==0)&&(TAKEN_BRANCH==0))
   if (HALTED==0)

   begin
	MEM_WB_type  <=  EX_MEM_type;
	MEM_WB_IR  <=  EX_MEM_IR;
          if ((RR_EX_IR[15:12]==Addition) && (RR_EX_IR[2:0]==ADD_NDU))
	  begin
//		EX_MEM_ALUout <= RR_EX_A + RR_EX_B;
	       if ((EX_MEM_ALUout == 17'b00000000000000000))		
			Zero = 1;

	       else if (EX_MEM_ALUout[16]==1)			
			Carry = 1;

	       else
		  begin
		     Zero = 0;
		     Carry= 0;
		  end	
	  end

	else if ((RR_EX_IR[15:12]==Addition) && (RR_EX_IR[2:0]==ADC_NDC) && (Carry==1))
	   begin
//		EX_MEM_ALUout <= RR_EX_A + RR_EX_B;
		if (EX_MEM_ALUout == 17'b0000000000000000)			
			Zero = 1;

		else if (EX_MEM_ALUout[16]==1)			
			Carry = 1;

	        else
		  begin
		     Zero = 0;
		     Carry= 0;
		  end
	   end

	else if ((RR_EX_IR[15:12]==Addition) && (RR_EX_IR[2:0]==ADZ_NDZ) && (Zero==1))
	  begin
//		EX_MEM_ALUout <= RR_EX_A + RR_EX_B;
		if (EX_MEM_ALUout == 17'b0000000000000000)
 			Zero = 1;

		else if (EX_MEM_ALUout[16]==1)			
			Carry = 1;
	        else
		   begin
		     Zero = 0;
		     Carry= 0;
		   end
	
	  end

	else if ((RR_EX_IR[15:12]==Nand) && (RR_EX_IR[2:0]==ADD_NDU))
	  begin
//		EX_MEM_ALUout <= RR_EX_A ~& RR_EX_B;
		if (EX_MEM_ALUout == 17'b0000000000000000)			
			Zero = 1;
		else 
			Zero = 0;
	  end	

	else if ((RR_EX_IR[15:12]==Nand) && (RR_EX_IR[2:0]==ADC_NDC) && (Carry==1))
	  begin
//		EX_MEM_ALUout <= RR_EX_A ~& RR_EX_B;
		if (EX_MEM_ALUout == 17'b0000000000000000)
			Zero = 1;
		else 
			Zero = 0;
	  end	

	else if ((RR_EX_IR[15:12]==Nand) && (RR_EX_IR[2:0]==ADZ_NDZ) && (Zero==1))
	  begin
//		EX_MEM_ALUout <= RR_EX_A ~& RR_EX_B;
		if (EX_MEM_ALUout == 17'b0000000000000000)
			Zero = 1;
		else 
			Zero = 0;
	  end

	else if (RR_EX_IR[15:12]==ADI)
	   begin
//		EX_MEM_ALUout <= RR_EX_A + RR_EX_Imm6;		//ALUout has the value to be stored in RB
		if (EX_MEM_ALUout == 17'b0000000000000000)
			Zero = 1;

		else if (EX_MEM_ALUout[16]==1)
			Carry = 1;

		else
		   begin
		     Zero = 0;
		     Carry= 0;
		   end
	   end
	
	else if (RR_EX_IR[15:12]==LW)
	   begin
//		EX_MEM_ALUout <= RR_EX_B+ RR_EX_Imm6;  //Memory adress. Value to be stored in RA
		//EX_MEM_A      <= RR_EX_A;
		if (EX_MEM_ALUout == 17'b0000000000000000)
			Zero = 1;
		else 
			Zero = 0;
	   end

	case(EX_MEM_IR[15:12])
	  Addition, Nand, ADI : MEM_WB_ALUout <=  EX_MEM_ALUout;
	  LHI, JAL, JLR	      : MEM_WB_A      <=  EX_MEM_A;
				//MEM_WB_IR  <=  RR_EX_IR;			
	  LW		      : MEM_WB_LMD  <= Mem[EX_MEM_ALUout];
	  SW		      : if (TAKEN_BRANCH == 0)		    //Disable write
				  Mem[EX_MEM_ALUout]  <=  EX_MEM_A;
	  LM                  : begin
				R0_M <= Mem[EX_MEM_ALUout];
				R1_M <= Mem[EX_MEM_ALUout + EX_MEM_Imm9[0]];
				R2_M <= Mem[EX_MEM_ALUout + EX_MEM_Imm9[0]+EX_MEM_Imm9[1]];
				R3_M <= Mem[EX_MEM_ALUout + EX_MEM_Imm9[0]+EX_MEM_Imm9[1]+ EX_MEM_Imm9[2]];
				R4_M <= Mem[EX_MEM_ALUout + EX_MEM_Imm9[0]+EX_MEM_Imm9[1]+ EX_MEM_Imm9[2]+ EX_MEM_Imm9[3]];
				R5_M <= Mem[EX_MEM_ALUout + EX_MEM_Imm9[0]+EX_MEM_Imm9[1]+ EX_MEM_Imm9[2]+ EX_MEM_Imm9[3]+ EX_MEM_Imm9[4]];
				R6_M <= Mem[EX_MEM_ALUout + EX_MEM_Imm9[0]+EX_MEM_Imm9[1]+ EX_MEM_Imm9[2]+ EX_MEM_Imm9[3]+ EX_MEM_Imm9[4]+ EX_MEM_Imm9[5]];
				R7_M <= Mem[EX_MEM_ALUout + EX_MEM_Imm9[0]+EX_MEM_Imm9[1]+ EX_MEM_Imm9[2]+ EX_MEM_Imm9[3]+ EX_MEM_Imm9[4]+ EX_MEM_Imm9[5]+ EX_MEM_Imm9[6]];
				end
	  SM		      : if (EX_MEM_Imm9[0]==1)
				  Mem[EX_MEM_ALUout]  <=  Reg[0];
				else if (EX_MEM_Imm9[1]==1)
				  Mem[EX_MEM_ALUout + EX_MEM_Imm9[0]] <= Reg[1];
				else if (EX_MEM_Imm9[2]==1)
				  Mem[EX_MEM_ALUout + EX_MEM_Imm9[0]+EX_MEM_Imm9[1]] <= Reg[2];
				else if (EX_MEM_Imm9[3]==1)
				  Mem[EX_MEM_ALUout + EX_MEM_Imm9[0]+EX_MEM_Imm9[1]+ EX_MEM_Imm9[2]] <= Reg[3];
				else if (EX_MEM_Imm9[4]==1)
				  Mem[EX_MEM_ALUout + EX_MEM_Imm9[0]+EX_MEM_Imm9[1]+ EX_MEM_Imm9[2]+ EX_MEM_Imm9[3]] <= Reg[4];
				else if (EX_MEM_Imm9[5]==1)
				  Mem[EX_MEM_ALUout + EX_MEM_Imm9[0]+EX_MEM_Imm9[1]+ EX_MEM_Imm9[2]+ EX_MEM_Imm9[3]+ EX_MEM_Imm9[4]] <= Reg[5];
				else if (EX_MEM_Imm9[6]==1)
				  Mem[EX_MEM_ALUout + EX_MEM_Imm9[0]+EX_MEM_Imm9[1]+ EX_MEM_Imm9[2]+ EX_MEM_Imm9[3]+ EX_MEM_Imm9[4]+ EX_MEM_Imm9[5]] <= Reg[6];
				else if (EX_MEM_Imm9[7]==1)
				  Mem[EX_MEM_ALUout + EX_MEM_Imm9[0]+EX_MEM_Imm9[1]+ EX_MEM_Imm9[2]+ EX_MEM_Imm9[3]+ EX_MEM_Imm9[4]+ EX_MEM_Imm9[5]+ EX_MEM_Imm9[6]] <= Reg[7];

//	  SM		      : if (EX_MEM_Imm9[0]==1)
//				Mem[EX_MEM_ALUout]  <=  Reg[0];
//				  if (EX_MEM_Imm9[1]==1)
//				  Mem[EX_MEM_ALUout + EX_MEM_Imm9[0]] <= Reg[1];
//				    if (EX_MEM_Imm9[2]==1)
//				    Mem[EX_MEM_ALUout + EX_MEM_Imm9[0]+EX_MEM_Imm9[1]] <= Reg[2];
//				      if (EX_MEM_Imm9[3]==1)
//				      Mem[EX_MEM_ALUout + EX_MEM_Imm9[0]+EX_MEM_Imm9[1]+ EX_MEM_Imm9[2]] <= Reg[3];
//		            		if (EX_MEM_Imm9[4]==1)
//				        Mem[EX_MEM_ALUout + EX_MEM_Imm9[0]+EX_MEM_Imm9[1]+ EX_MEM_Imm9[2]+ EX_MEM_Imm9[3]] <= Reg[4];
//				          if (EX_MEM_Imm9[5]==1)
//				  	  Mem[EX_MEM_ALUout + EX_MEM_Imm9[0]+EX_MEM_Imm9[1]+ EX_MEM_Imm9[2]+ EX_MEM_Imm9[3]+ EX_MEM_Imm9[4]] <= Reg[5];
//				            if (EX_MEM_Imm9[6]==1)
//				       	      Mem[EX_MEM_ALUout + EX_MEM_Imm9[0]+EX_MEM_Imm9[1]+ EX_MEM_Imm9[2]+ EX_MEM_Imm9[3]+ EX_MEM_Imm9[4]+ EX_MEM_Imm9[5]] <= Reg[6];
//				 	      if (EX_MEM_Imm9[7]==1)
//				        Mem[EX_MEM_ALUout + EX_MEM_Imm9[0]+EX_MEM_Imm9[1]+ EX_MEM_Imm9[2]+ EX_MEM_Imm9[3]+ EX_MEM_Imm9[4]+ EX_MEM_Imm9[5]+ EX_MEM_Imm9[6]] <= Reg[7];

	endcase
   end
	  
//=========================== WB Stage ==================================//

always @(posedge clk2)
   begin
      if ((TAKEN_BRANCH == 0)&&(EX_MEM_IR[15:12]!=JAL)&&(EX_MEM_IR[15:12]!=JLR))		//Disable write if branch taken

      case(MEM_WB_IR[15:12])
	Addition, Nand  : Reg[MEM_WB_IR[5:3]]  <=  MEM_WB_ALUout;	//RC
		ADI     : Reg[MEM_WB_IR[8:6]]  <=  MEM_WB_ALUout;	//RB
		LW	: Reg[MEM_WB_IR[11:9]]  <=  MEM_WB_LMD;		//RA
	       LHI	: Reg[MEM_WB_IR[11:9]]  <=  MEM_WB_A;		//RA
		HALT    : HALTED <= 1'b1;
		LM	: if (EX_MEM_Imm9[0]==1)
			     Reg[0] <= R0_M;
			  else if (EX_MEM_Imm9[1]==1)
			     Reg[1] <= R1_M;
			  else if (EX_MEM_Imm9[2]==1)
			     Reg[2] <= R2_M;
			  else if (EX_MEM_Imm9[3]==1)
			     Reg[3] <= R3_M;
			  else if (EX_MEM_Imm9[4]==1)
			     Reg[4] <= R4_M;
			  else if (EX_MEM_Imm9[5]==1)
			     Reg[5] <= R5_M;
			  else if (EX_MEM_Imm9[6]==1)
			     Reg[6] <= R6_M;
			  else if (EX_MEM_Imm9[7]==1)
			     Reg[7] <= R7_M;
      endcase

      else if ((EX_MEM_IR[15:12]==JAL)||(EX_MEM_IR[15:12]==JLR))			//These 2 lines are extras
          Reg[MEM_WB_IR[11:9]]  <=  MEM_WB_A;
	   
   end

endmodule






















