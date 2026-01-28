module count_rotations (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire signed [7:0] arr_0,
    input wire signed [7:0] arr_1,
    input wire signed [7:0] arr_2,
    input wire signed [7:0] arr_3,
    input wire signed [7:0] arr_4,
    input wire signed [7:0] arr_5,
    input wire signed [7:0] arr_6,
    input wire signed [7:0] arr_7,
    input wire [3:0] array_len,
    output reg [3:0] rotation_count,
    output reg done
);

    // State machine declarations
    localparam [2:0] IDLE      = 3'd0;
    localparam [2:0] CHECK     = 3'd1;
    localparam [2:0] UPDATE    = 3'd2;
    localparam [2:0] FINISH    = 3'd3;
    localparam [2:0] DONE      = 3'd4;

    reg [2:0] state;
    reg [3:0] index;           // Current index being checked
    reg found;                 // Flag to indicate rotation found
    reg [3:0] result;          // Stores the rotation count
    reg [3:0] len_reg;         // Store array length
    
    // Internal signals for array access
    reg signed [7:0] current_elem;
    reg signed [7:0] prev_elem;

    // Combinational logic to select array elements
    always @(*) begin
        case (index)
            4'd0: current_elem = arr_0;
            4'd1: current_elem = arr_1;
            4'd2: current_elem = arr_2;
            4'd3: current_elem = arr_3;
            4'd4: current_elem = arr_4;
            4'd5: current_elem = arr_5;
            4'd6: current_elem = arr_6;
            4'd7: current_elem = arr_7;
            default: current_elem = 8'd0;
        endcase
        
        case (index - 4'd1)
            4'd0: prev_elem = arr_0;
            4'd1: prev_elem = arr_1;
            4'd2: prev_elem = arr_2;
            4'd3: prev_elem = arr_3;
            4'd4: prev_elem = arr_4;
            4'd5: prev_elem = arr_5;
            4'd6: prev_elem = arr_6;
            4'd7: prev_elem = arr_7;
            default: prev_elem = 8'd0;
        endcase
    end

    // Sequential FSM
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            rotation_count <= 4'd0;
            done <= 1'b0;
            index <= 4'd0;
            found <= 1'b0;
            result <= 4'd0;
            len_reg <= 4'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    found <= 1'b0;
                    result <= 4'd0;
                    index <= 4'd1;  // Start checking from i=1
                    if (start) begin
                        len_reg <= array_len;
                        state <= CHECK;
                    end
                end
                
                CHECK: begin
                    if (index < len_reg) begin
                        if (!found) begin
                            // Check if current < previous
                            if (current_elem < prev_elem) begin
                                found <= 1'b1;
                                result <= index;
                            end
                        end
                        state <= UPDATE;
                    end else begin
                        // Done checking all elements
                        state <= FINISH;
                    end
                end
                
                UPDATE: begin
                    index <= index + 4'd1;
                    state <= CHECK;
                end
                
                FINISH: begin
                    if (found) begin
                        rotation_count <= result;
                    end else begin
                        rotation_count <= 4'd0;
                    end
                    done <= 1'b1;
                    state <= DONE;
                end
                
                DONE: begin
                    done <= 1'b0;
                    state <= IDLE;
                end
                
                default: begin
                    state <= IDLE;
                end
            endcase
        end
    end

endmodule