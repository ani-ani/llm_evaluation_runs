module string_length_sum (
    input wire clk,
    input wire rst_n,
    input wire start,

    // Input: 8 names, each 8 characters (8-bit ASCII each)
    // Interface: names_{name_idx}_{char_idx}
    input wire [7:0] names_0_0, names_0_1, names_0_2, names_0_3, names_0_4, names_0_5, names_0_6, names_0_7,
    input wire [7:0] names_1_0, names_1_1, names_1_2, names_1_3, names_1_4, names_1_5, names_1_6, names_1_7,
    input wire [7:0] names_2_0, names_2_1, names_2_2, names_2_3, names_2_4, names_2_5, names_2_6, names_2_7,
    input wire [7:0] names_3_0, names_3_1, names_3_2, names_3_3, names_3_4, names_3_5, names_3_6, names_3_7,
    input wire [7:0] names_4_0, names_4_1, names_4_2, names_4_3, names_4_4, names_4_5, names_4_6, names_4_7,
    input wire [7:0] names_5_0, names_5_1, names_5_2, names_5_3, names_5_4, names_5_5, names_5_6, names_5_7,
    input wire [7:0] names_6_0, names_6_1, names_6_2, names_6_3, names_6_4, names_6_5, names_6_6, names_6_7,
    input wire [7:0] names_7_0, names_7_1, names_7_2, names_7_3, names_7_4, names_7_5, names_7_6, names_7_7,

    output reg [15:0] result,
    output reg done
);

    // State definitions
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] VALIDATE_NAME = 3'd1;
    localparam [2:0] COUNT_LENGTH = 3'd2;
    localparam [2:0] UPDATE_ACCUM = 3'd3;
    localparam [2:0] NEXT_NAME = 3'd4;
    localparam [2:0] FINISHED = 3'd5;
    
    // Internal registers
    reg [2:0] state;
    reg [2:0] name_idx;
    reg [3:0] char_idx;
    reg [15:0] accumulator;
    reg [3:0] current_length;
    reg name_valid;

    // Helper: Get character value based on indices
    wire [7:0] current_char;
    assign current_char = get_char(name_idx, char_idx);
    
    function automatic [7:0] get_char(input [2:0] n_idx, input [3:0] c_idx);
        case (n_idx)
            3'd0: case (c_idx)
                4'd0: return names_0_0; 4'd1: return names_0_1; 4'd2: return names_0_2; 4'd3: return names_0_3,
                4'd4: return names_0_4; 4'd5: return names_0_5; 4'd6: return names_0_6; default: return names_0_7; endcase
            3'd1: case (c_idx)
                4'd0: return names_1_0; 4'd1: return names_1_1; 4'd2: return names_1_2; 4'd3: return names_1_3,
                4'd4: return names_1_4; 4'd5: return names_1_5; 4'd6: return names_1_6; default: return names_1_7; endcase
            3'd2: case (c_idx)
                4'd0: return names_2_0; 4'd1: return names_2_1; 4'd2: return names_2_2; 4'd3: return names_2_3,
                4'd4: return names_2_4; 4'd5: return names_2_5; 4'd6: return names_2_6; default: return names_2_7; endcase
            3'd3: case (c_idx)
                4'd0: return names_3_0; 4'd1: return names_3_1; 4'd2: return names_3_2; 4'd3: return names_3_3,
                4'd4: return names_3_4; 4'd5: return names_3_5; 4'd6: return names_3_6; default: return names_3_7; endcase
            3'd4: case (c_idx)
                4'd0: return names_4_0; 4'd1: return names_4_1; 4'd2: return names_4_2; 4'd3: return names_4_3,
                4'd4: return names_4_4; 4'd5: return names_4_5; 4'd6: return names_4_6; default: return names_4_7; endcase
            3'd5: case (c_idx)
                4'd0: return names_5_0; 4'd1: return names_5_1; 4'd2: return names_5_2; 4'd3: return names_5_3,
                4'd4: return names_5_4; 4'd5: return names_5_5; 4'd6: return names_5_6; default: return names_5_7; endcase
            3'd6: case (c_idx)
                4'd0: return names_6_0; 4'd1: return names_6_1; 4'd2: return names_6_2; 4'd3: return names_6_3,
                4'd4: return names_6_4; 4'd5: return names_6_5; 4'd6: return names_6_6; default: return names_6_7; endcase
            default: case (c_idx)
                4'd0: return names_7_0; 4'd1: return names_7_1; 4'd2: return names_7_2; 4'd3: return names_7_3,
                4'd4: return names_7_4; 4'd5: return names_7_5; 4'd6: return names_7_6; default: return names_7_7; endcase
        endcase
    endfunction
    
    // Character property checks
    wire is_upper = (current_char >= 8'd65) && (current_char <= 8'd90);
    wire is_lower = (current_char >= 8'd97) && (current_char <= 8'd122);
    wire is_null = (current_char == 8'd0);
    
    // Main state machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 16'd0;
            done <= 1'b0;
            accumulator <= 16'd0;
            name_idx <= 3'd0;
            char_idx <= 4'd0;
            current_length <= 4'd0;
            name_valid <= 1'b0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        state <= VALIDATE_NAME;
                        accumulator <= 16'd0;
                        name_idx <= 3'd0;
                        char_idx <= 4'd0;
                        name_valid <= 1'b1;
                    end
                end
                
                VALIDATE_NAME: begin
                    // Check first char (must be uppercase)
                    if (char_idx == 4'd0) begin
                        if (!is_upper) begin
                            name_valid <= 1'b0;
                        end
                        char_idx <= 4'd1;
                    end else if (char_idx < 4'd8) begin
                        // Check remaining chars (must be lowercase or null)
                        if (name_valid && !is_null && !is_lower) begin
                            name_valid <= 1'b0;
                        end
                        char_idx <= char_idx + 1'b1;
                    end else begin
                        // Validation complete
                        char_idx <= 4'd0;
                        if (name_valid) begin
                            state <= COUNT_LENGTH;
                        end else begin
                            state <= NEXT_NAME;
                        end
                    end
                end
                
                COUNT_LENGTH: begin
                    if (char_idx < 4'd8) begin
                        if (!is_null) begin
                            current_length <= current_length + 1'b1;
                        end
                        char_idx <= char_idx + 1'b1;
                    end else begin
                        // Length counting complete
                        state <= UPDATE_ACCUM;
                        char_idx <= 4'd0;
                    end
                end
                
                UPDATE_ACCUM: begin
                    accumulator <= accumulator + {12'd0, current_length};
                    current_length <= 4'd0;
                    state <= NEXT_NAME;
                end
                
                NEXT_NAME: begin
                    if (name_idx == 3'd7) begin
                        state <= FINISHED;
                    end else begin
                        name_idx <= name_idx + 1'b1;
                        char_idx <= 4'd0;
                        name_valid <= 1'b1;
                        state <= VALIDATE_NAME;
                    end
                end
                
                FINISHED: begin
                    result <= accumulator;
                    done <= 1'b1;
                    state <= IDLE;
                end
                
                default: state <= IDLE;
            endcase
        end
    end

endmodule