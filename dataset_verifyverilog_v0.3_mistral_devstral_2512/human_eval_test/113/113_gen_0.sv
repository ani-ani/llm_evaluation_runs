module odd_count(
    input clk,
    input rst_n,
    input start,
    input [7:0] char_0, char_1, char_2, char_3, char_4, char_5, char_6, char_7,
    output reg [7:0] out_0, out_1, out_2, out_3, out_4, out_5, out_6, out_7, out_8, out_9, out_10, out_11, out_12, out_13, out_14, out_15,
    output reg done
);

    // State declarations
    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] COUNT_ODD = 2'd1;
    localparam [1:0] GEN_OUTPUT = 2'd2;
    localparam [1:0] DONE_STATE = 2'd3;

    reg [1:0] state, next_state;
    reg [3:0] count;
    reg [7:0] count_char;
    reg [3:0] cycle_counter;
    localparam [3:0] MAX_CYCLES = 4'd20;

    // Combinational logic for odd detection
    wire is_odd_0 = (char_0[3:0] >= 4'd1 && char_0[3:0] <= 4'd9) && (char_0[0] == 1'b1);
    wire is_odd_1 = (char_1[3:0] >= 4'd1 && char_1[3:0] <= 4'd9) && (char_1[0] == 1'b1);
    wire is_odd_2 = (char_2[3:0] >= 4'd1 && char_2[3:0] <= 4'd9) && (char_2[0] == 1'b1);
    wire is_odd_3 = (char_3[3:0] >= 4'd1 && char_3[3:0] <= 4'd9) && (char_3[0] == 1'b1);
    wire is_odd_4 = (char_4[3:0] >= 4'd1 && char_4[3:0] <= 4'd9) && (char_4[0] == 1'b1);
    wire is_odd_5 = (char_5[3:0] >= 4'd1 && char_5[3:0] <= 4'd9) && (char_5[0] == 1'b1);
    wire is_odd_6 = (char_6[3:0] >= 4'd1 && char_6[3:0] <= 4'd9) && (char_6[0] == 1'b1);
    wire is_odd_7 = (char_7[3:0] >= 4'd1 && char_7[3:0] <= 4'd9) && (char_7[0] == 1'b1);

    // State machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            count <= 4'd0;
            count_char <= 8'd0;
            cycle_counter <= 4'd0;
            done <= 1'b0;
            out_0 <= 8'd0;
            out_1 <= 8'd0;
            out_2 <= 8'd0;
            out_3 <= 8'd0;
            out_4 <= 8'd0;
            out_5 <= 8'd0;
            out_6 <= 8'd0;
            out_7 <= 8'd0;
            out_8 <= 8'd0;
            out_9 <= 8'd0;
            out_10 <= 8'd0;
            out_11 <= 8'd0;
            out_12 <= 8'd0;
            out_13 <= 8'd0;
            out_14 <= 8'd0;
            out_15 <= 8'd0;
        end else begin
            state <= next_state;
            
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_counter <= 4'd0;
                    if (start) begin
                        next_state <= COUNT_ODD;
                    end else begin
                        next_state <= IDLE;
                    end
                end
                
                COUNT_ODD: begin
                    cycle_counter <= cycle_counter + 4'd1;
                    if (cycle_counter == 4'd1) begin
                        count <= is_odd_0 + is_odd_1 + is_odd_2 + is_odd_3 + is_odd_4 + is_odd_5 + is_odd_6 + is_odd_7;
                    end
                    if (cycle_counter >= 4'd8) begin
                        next_state <= GEN_OUTPUT;
                    end else begin
                        next_state <= COUNT_ODD;
                    end
                end
                
                GEN_OUTPUT: begin
                    cycle_counter <= cycle_counter + 4'd1;
                    if (cycle_counter == 4'd9) begin
                        count_char <= 8'h30 + count;
                        out_0 <= count_char;
                        out_1 <= 8'h20;  // space
                        out_2 <= 8'h6f;  // 'o'
                        out_3 <= 8'h64;  // 'd'
                        out_4 <= 8'h64;  // 'd'
                        out_5 <= 8'h20;  // space
                        out_6 <= 8'h65;  // 'e'
                        out_7 <= 8'h6c;  // 'l'
                        out_8 <= 8'h65;  // 'e'
                        out_9 <= 8'h6d;  // 'm'
                        out_10 <= 8'h65; // 'e'
                        out_11 <= 8'h6e; // 'n'
                        out_12 <= 8'h74; // 't'
                        out_13 <= 8'h73; // 's'
                        out_14 <= 8'h20; // space
                        out_15 <= 8'h20; // space
                    end
                    if (cycle_counter >= 4'd20) begin
                        next_state <= DONE_STATE;
                    end else begin
                        next_state <= GEN_OUTPUT;
                    end
                end
                
                DONE_STATE: begin
                    done <= 1'b1;
                    next_state <= IDLE;
                end
                
                default: begin
                    next_state <= IDLE;
                    done <= 1'b0;
                end
            endcase
        end
    end
endmodule