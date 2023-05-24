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
    reg [3:0] cs, ns;
    reg [2:0] RD_cnt, VEC_cnt, OP_cnt, SORT_cnt;
    reg [10:0] X_input [6:0];
    reg [10:0] Y_input [6:0];
    reg signed [11:0] X_vector [4:0];
    reg signed [11:0] Y_vector [4:0];
    reg signed [11:0] a, b, c, d;
    reg signed [23:0] OP [4:0];
    
    reg signed [11:0] InX [5:0];
    reg signed [11:0] InY [5:0];
    reg signed [23:0] In_OuterProduct [5:0];


    // -------------------------------------------------
	//                Parameters                 
	// -------------------------------------------------
    integer i;
    parameter IDLE = 0;
    parameter RD = 1;
    parameter VECTOR = 2;
    parameter OUTER_PRODUCT = 3;
    parameter SORT = 4;
    parameter IN_VECTOR = 5;
    parameter IN_OP = 6;
    parameter OUTPUT = 7;

    // -------------------------------------------------
	//                Finite State Machine                 
	// -------------------------------------------------

    always@(posedge clk or posedge reset) begin
        if (reset) begin
            cs <= IDLE;
        end
        else begin
            cs <= ns;
        end
    end

    always @(*) begin
        case (cs)
            IDLE : ns = RD;
            RD : ns = (RD_cnt == 3'd6) ? VECTOR : RD;
            VECTOR : ns = (VEC_cnt == 3'd4) ? OUTER_PRODUCT : VECTOR;
            OUTER_PRODUCT : ns = (OP_cnt == 3'd4) ? SORT : OUTER_PRODUCT;
            SORT : ns = (SORT_cnt == 3'd4) ? IN_VECTOR : SORT;
            IN_VECTOR : ns = IN_OP;
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
                    X_input[RD_cnt] <= {1'd0, X};
                    Y_input[RD_cnt] <= {1'd0, Y};
                end
                SORT : begin
                    case (SORT_cnt)
                        3'd0, 3'd2, 3'd4 : begin
                            if (OP[0] > OP[1]) begin
                                X_input[2] <= X_input[3];
                                X_input[3] <= X_input[2];
                                Y_input[2] <= Y_input[3];
                                Y_input[3] <= Y_input[2];
                            end
                            if (OP[2] > OP[3]) begin
                                X_input[4] <= X_input[5];
                                X_input[5] <= X_input[4];
                                Y_input[4] <= Y_input[5];
                                Y_input[5] <= Y_input[4];
                            end
                        end
                        3'd1, 3'd3 : begin
                            if (OP[1] > OP[2]) begin
                                X_input[3] <= X_input[4];
                                X_input[4] <= X_input[3];
                                Y_input[3] <= Y_input[4];
                                Y_input[4] <= Y_input[3];
                            end
                            if (OP[3] > OP[4]) begin
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

    always@(posedge clk or posedge reset) begin
        if (reset) begin
            for (i = 0; i < 5; i = i+1) begin
                X_vector[i] <= 0;
                Y_vector[i] <= 0;
            end
        end
        else begin
            if (cs == VECTOR) begin
                case (VEC_cnt)
                    3'd0 : {X_vector[0], Y_vector[0]} <= {($signed(X_input[2]) - $signed(X_input[1])), ($signed(Y_input[2]) - $signed(Y_input[1]))};
                    3'd1 : {X_vector[1], Y_vector[1]} <= {($signed(X_input[3]) - $signed(X_input[1])), ($signed(Y_input[3]) - $signed(Y_input[1]))};
                    3'd2 : {X_vector[2], Y_vector[2]} <= {($signed(X_input[4]) - $signed(X_input[1])), ($signed(Y_input[4]) - $signed(Y_input[1]))};
                    3'd3 : {X_vector[3], Y_vector[3]} <= {($signed(X_input[5]) - $signed(X_input[1])), ($signed(Y_input[5]) - $signed(Y_input[1]))};
                    3'd4 : {X_vector[4], Y_vector[4]} <= {($signed(X_input[6]) - $signed(X_input[1])), ($signed(Y_input[6]) - $signed(Y_input[1]))};
                endcase
            end
        end
    end

    always@(posedge clk or posedge reset) begin
        if (reset) begin
            VEC_cnt <= 0;
        end
        else begin
            VEC_cnt <= (cs == VECTOR) ? (VEC_cnt + 1) : 0;
        end
    end

    // -------------------------------------------------
	//                Outer_Product                 
	// -------------------------------------------------


    always@(posedge clk or posedge reset) begin
        if (reset) begin
            for (i = 0; i < 5; i = i+1) begin
                OP[i] <= 0;
            end
        end
        else begin
            if (cs == OUTER_PRODUCT) begin
                OP[OP_cnt] <= (a * d) - (b * c);
            end
            else if (cs == SORT) begin
                case (SORT_cnt)
                    3'd0, 3'd2, 3'd4 : begin
                        if (OP[0] > OP[1]) begin
                            OP[0] <= OP[1];
                            OP[1] <= OP[0];
                        end
                        if (OP[2] > OP[3]) begin
                            OP[2] <= OP[3];
                            OP[3] <= OP[2];
                        end
                    end
                    3'd1, 3'd3 : begin
                        if (OP[1] > OP[2]) begin
                            OP[1] <= OP[2];
                            OP[2] <= OP[1];
                        end
                        if (OP[3] > OP[4]) begin
                            OP[3] <= OP[4];
                            OP[4] <= OP[3];
                        end
                    end
                endcase
            end
        end
    end

    always @(*) begin
        if (cs == OUTER_PRODUCT) begin
            case (OP_cnt)
                3'd0 : begin
                    a = X_vector[0]; b = Y_vector[0]; c = X_vector[0]; d = Y_vector[0];
                end
                3'd1 : begin
                    a = X_vector[1]; b = Y_vector[1]; c = X_vector[0]; d = Y_vector[0];
                end
                3'd2 : begin
                    a = X_vector[2]; b = Y_vector[2]; c = X_vector[0]; d = Y_vector[0];
                end
                3'd3 : begin
                    a = X_vector[3]; b = Y_vector[3]; c = X_vector[0]; d = Y_vector[0];
                end
                3'd4 : begin
                    a = X_vector[4]; b = Y_vector[4]; c = X_vector[0]; d = Y_vector[0];
                end
                default : begin
                    a = 0; b = 0; c = 0; d = 0;
                end
            endcase
        end
        else if (cs == IN_OP) begin
            case (OP_cnt)
                3'd0 : begin
                    a = InX[1]; b = InY[1]; c = InX[0]; d = InY[0];
                end
                3'd1 : begin
                    a = InX[2]; b = InY[2]; c = InX[1]; d = InY[1];
                end
                3'd2 : begin
                    a = InX[3]; b = InY[3]; c = InX[2]; d = InY[2];
                end
                3'd3 : begin
                    a = InX[4]; b = InY[4]; c = InX[3]; d = InY[3];
                end
                3'd4 : begin
                    a = InX[5]; b = InY[5]; c = InX[4]; d = InY[4];
                end
                3'd5 : begin
                    a = InX[0]; b = InY[0]; c = InX[5]; d = InY[5];
                end
                default : begin
                    a = 0; b = 0; c = 0; d = 0;
                end
            endcase
        end
        else begin
            a = 0; b = 0; c = 0; d = 0;
        end
    end

    always@(posedge clk or posedge reset) begin  // Outer_Product counter
        if (reset) begin
            OP_cnt <= 0;
        end
        else begin
            OP_cnt <= (cs == OUTER_PRODUCT || cs == IN_OP) ? (OP_cnt + 1) : 0;
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

    always@(posedge clk or posedge reset) begin
        if (reset) begin
            for (i = 0; i < 6; i = i+1) begin
                InX[i] <= 0; InY[i] <= 0;
            end
        end
        else begin
            if (cs == IN_VECTOR) begin
                for (i = 0; i < 6; i = i+1) begin
                    InX[i] <= $signed(X_input[i+1]) - $signed(X_input[0]);
                    InY[i] <= $signed(Y_input[i+1]) - $signed(Y_input[0]);
                end
            end
        end
    end

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
                In_OuterProduct[OP_cnt] <= (a * d) - (b * c);
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

