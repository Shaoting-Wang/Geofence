module geofence ( clk,reset,X,Y,valid,is_inside);
    // -------------------------------------------------
	//                Inputs or Outputs                 
	// -------------------------------------------------
    input clk;
    input reset;
    input [9:0] X;
    input [9:0] Y;
    output valid;
    output reg is_inside;

    // ------------------------------------------------- 
	//                Regs or Wires                 
	// -------------------------------------------------
    reg [2:0] cs, ns;
    reg [2:0] RD_cnt, VEC_cnt, OP_cnt, SORT_cnt;
    reg signed [10:0] X_input [6:0];
    reg signed [10:0] Y_input [6:0];
    reg signed [11:0] X_vector [5:0];
    reg signed [11:0] Y_vector [5:0];
    reg signed [11:0] a1, a2, b1, b2, c1, c2, d1, d2;
    reg signed [23:0] OP1, OP2;
    
    reg signed [23:0] In_OuterProduct [5:0];


    // -------------------------------------------------
	//                Parameters                 
	// -------------------------------------------------
    integer i;
    parameter IDLE = 0;
    parameter RD = 1;
    parameter VECTOR = 2;
    parameter SORT = 3;
    parameter IN_VEC = 4;
    parameter IN_OP = 5;
    parameter OUTPUT = 6;

    // -------------------------------------------------
	//                Finite State Machine                 
	// -------------------------------------------------

    always@(posedge clk or posedge reset) begin
        if (reset) begin
            cs <= RD;
        end
        else begin
            cs <= ns;
        end
    end

    always @(*) begin
        case (cs)
            IDLE : ns = RD;
            RD : ns = (RD_cnt == 3'd6) ? VECTOR : RD;
            VECTOR : ns = (VEC_cnt == 3'd4) ? SORT : VECTOR;
            SORT : ns = (SORT_cnt == 3'd4) ? IN_VEC : SORT;
            IN_VEC : ns = (VEC_cnt == 3'd5) ? IN_OP : IN_VEC;
            IN_OP : ns = (OP_cnt == 3'd5) ? OUTPUT : IN_OP;
            OUTPUT : ns = RD;
            default : ns = cs;
        endcase
    end

    // -------------------------------------------------
	//                Recieve_Data                 
	// -------------------------------------------------

    always@(posedge clk or posedge reset) begin // RD_cnt
        if (reset) begin
            RD_cnt <= 0;
        end
        else begin
            RD_cnt <= (cs == RD) ? (RD_cnt + 1) : 0;
        end
    end

    always@(posedge clk or posedge reset) begin // Restore
        if (reset) begin
            for(i = 0; i < 7; i = i+1) begin
                X_input[i] <= 0;
                Y_input[i] <= 0;
            end
        end
        else begin
            case (cs)
                RD : begin
                    X_input[RD_cnt] <= {$signed(1'd0), $signed(X)};
                    Y_input[RD_cnt] <= {$signed(1'd0), $signed(Y)};
                end
                SORT : begin
                    case (SORT_cnt)
                        3'd0, 3'd2, 3'd4 : begin
                            if (OP1[23] == 0) begin
                                X_input[2] <= X_input[3];
                                X_input[3] <= X_input[2];
                                Y_input[2] <= Y_input[3];
                                Y_input[3] <= Y_input[2];
                            end
                            if (OP2[23] == 0) begin
                                X_input[4] <= X_input[5];
                                X_input[5] <= X_input[4];
                                Y_input[4] <= Y_input[5];
                                Y_input[5] <= Y_input[4];
                            end
                        end
                        3'd1, 3'd3 : begin
                            if (OP1[23] == 0) begin
                                X_input[3] <= X_input[4];
                                X_input[4] <= X_input[3];
                                Y_input[3] <= Y_input[4];
                                Y_input[4] <= Y_input[3];
                            end
                            if (OP2[23] == 0) begin
                                X_input[5] <= X_input[6];
                                X_input[6] <= X_input[5];
                                Y_input[5] <= Y_input[6];
                                Y_input[6] <= Y_input[5];
                            end
                        end
                    endcase
                end
            endcase
        end
    end

    // -------------------------------------------------
	//                Vector                 
	// -------------------------------------------------

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            for (i = 0; i < 6; i = i+1) begin
                X_vector[i] <= 0; Y_vector[i] <= 0;
            end
        end
        else begin
            case (cs)
                VECTOR : begin
                    X_vector[VEC_cnt] <= X_input[VEC_cnt+2] - X_input[1]; Y_vector[VEC_cnt] <= Y_input[VEC_cnt+2] - Y_input[1];
                end
                SORT : begin
                    case (SORT_cnt)
                        3'd0, 3'd2, 3'd4 : begin
                            if (OP1[23] == 0) begin
                                X_vector[0] <= X_vector[1];
                                X_vector[1] <= X_vector[0];
                                Y_vector[0] <= Y_vector[1];
                                Y_vector[1] <= Y_vector[0];
                            end
                            if (OP2[23] == 0) begin
                                X_vector[2] <= X_vector[3];
                                X_vector[3] <= X_vector[2];
                                Y_vector[2] <= Y_vector[3];
                                Y_vector[3] <= Y_vector[2];
                            end
                        end
                        3'd1, 3'd3 : begin
                            if (OP1[23] == 0) begin
                                X_vector[1] <= X_vector[2];
                                X_vector[2] <= X_vector[1];
                                Y_vector[1] <= Y_vector[2];
                                Y_vector[2] <= Y_vector[1];
                            end
                            if (OP2[23] == 0) begin
                                X_vector[3] <= X_vector[4];
                                X_vector[4] <= X_vector[3];
                                Y_vector[3] <= Y_vector[4];
                                Y_vector[4] <= Y_vector[3];
                            end
                        end
                    endcase
                end
                IN_VEC : begin
                    X_vector[VEC_cnt] <= X_input[VEC_cnt+1] - X_input[0]; Y_vector[VEC_cnt] <= Y_input[VEC_cnt+1] - Y_input[0];
                end
            endcase
        end
    end

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            VEC_cnt <= 0;
        end
        else begin
            VEC_cnt <= (cs == VECTOR || cs == IN_VEC) ? (VEC_cnt + 1) : 0;
        end
    end
        
    // -------------------------------------------------
	//                Outer_Product                 
	// -------------------------------------------------


    always @(*) begin
       OP1 = (a1 * d1) - (b1 * c1); 
       OP2 = (a2 * d2) - (b2 * c2);
    end

    always @(*) begin
        case (cs)
            SORT : begin
                case (SORT_cnt)
                    3'd0, 3'd2, 3'd4 : begin
                        a1 = X_vector[0]; b1 = Y_vector[0]; c1 = X_vector[1]; d1 = Y_vector[1]; a2 = X_vector[2]; b2 = Y_vector[2]; c2 = X_vector[3]; d2 = Y_vector[3];
                    end
                    3'd1, 3'd3 : begin
                        a1 = X_vector[1]; b1 = Y_vector[1]; c1 = X_vector[2]; d1 = Y_vector[2]; a2 = X_vector[3]; b2 = Y_vector[3]; c2 = X_vector[4]; d2 = Y_vector[4];
                    end
                    default : begin
                        a1 = 0; b1 = 0; c1 = 0; d1 = 0; a2 = 0; b2 = 0; c2 = 0; d2 = 0;
                    end
                endcase
            end
            IN_OP : begin
                case (OP_cnt)
                    3'd0 : begin
                        a1 = X_vector[0]; b1 = Y_vector[0]; c1 = X_vector[5]; d1 = Y_vector[5];
                        a2 = 0; b2 = 0; c2 = 0; d2 = 0;
                    end
                    3'd1 : begin
                        a1 = X_vector[1]; b1 = Y_vector[1]; c1 = X_vector[0]; d1 = Y_vector[0];
                        a2 = 0; b2 = 0; c2 = 0; d2 = 0;
                    end
                    3'd2 : begin
                        a1 = X_vector[2]; b1 = Y_vector[2]; c1 = X_vector[1]; d1 = Y_vector[1];
                        a2 = 0; b2 = 0; c2 = 0; d2 = 0;
                    end
                    3'd3 : begin
                        a1 = X_vector[3]; b1 = Y_vector[3]; c1 = X_vector[2]; d1 = Y_vector[2];
                        a2 = 0; b2 = 0; c2 = 0; d2 = 0;
                    end
                    3'd4 : begin
                        a1 = X_vector[4]; b1 = Y_vector[4]; c1 = X_vector[3]; d1 = Y_vector[3];
                        a2 = 0; b2 = 0; c2 = 0; d2 = 0;
                    end
                    3'd5 : begin
                        a1 = X_vector[5]; b1 = Y_vector[5]; c1 = X_vector[4]; d1 = Y_vector[4];
                        a2 = 0; b2 = 0; c2 = 0; d2 = 0;
                    end
                    default : begin
                        a1 = 0; b1 = 0; c1 = 0; d1 = 0; a2 = 0; b2 = 0; c2 = 0; d2 = 0;
                    end
                endcase
            end
            default : begin
                a1 = 0; b1 = 0; c1 = 0; d1 = 0; a2 = 0; b2 = 0; c2 = 0; d2 = 0;
            end
        endcase
    end

    always@(posedge clk or posedge reset) begin  // Outer_Product counter
        if (reset) begin
            OP_cnt <= 0;
        end
        else begin
            OP_cnt <= (cs == IN_OP) ? (OP_cnt + 1) : 0;
        end
    end

    // -------------------------------------------------
	//                      Sort                 
	// -------------------------------------------------

    always@(posedge clk or posedge reset) begin
        if (reset) begin
            SORT_cnt <= 0;
        end
        else begin
            SORT_cnt <= (cs == SORT) ? (SORT_cnt + 1) : 0;
        end
    end

    // -------------------------------------------------
	//                   IN_VECTOR                 
	// -------------------------------------------------

    // -------------------------------------------------
	//                      IN_OP                 
	// -------------------------------------------------

    always@(posedge clk or posedge reset) begin
        if (reset) begin
            for (i = 0; i < 6; i = i+1) begin
                In_OuterProduct[i] <= 0;
            end
        end
        else begin
            if (cs == IN_OP) begin
                In_OuterProduct[OP_cnt] <= OP1;
            end
        end
    end
    // -------------------------------------------------
	//                      OUTPUT                 
	// -------------------------------------------------

    assign valid = (cs == OUTPUT) ? 1'd1 : 1'd0;

    always @(*) begin
        if (In_OuterProduct[0][23] == In_OuterProduct[1][23] &&  In_OuterProduct[1][23] == In_OuterProduct[2][23] && In_OuterProduct[2][23] == In_OuterProduct[3][23] && In_OuterProduct[3][23] == In_OuterProduct[4][23] && In_OuterProduct[4][23] == In_OuterProduct[5][23] ) begin
            is_inside = 1'd1;
        end
        else begin
            is_inside = 1'd0;
        end
    end

endmodule
