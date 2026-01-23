module largest_non_square (
    input clk,
    input rst_n,
    input start,
    input [15:0] arr_0, arr_1, arr_2, arr_3, arr_4, arr_5, arr_6, arr_7,
    output reg [15:0] result,
    output reg done
);

// State definitions
localparam [2:0] IDLE  = 3'd0;
localparam [2:0] INIT  = 3'd1;
localparam [2:0] CHECK = 3'd2;
localparam [2:0] UPDATE = 3'd3;
localparam [2:0] NEXT  = 3'd4;
localparam [2:0] DONE  = 3'd5;

reg [2:0] state;
reg [2:0] current_index;
reg signed [15:0] max_val;  // Signed for comparison
reg signed [15:0] current_val; // Signed for comparison
reg [7:0] y;  // Counter for square root (0-181)
reg checking; // Flag to avoid infinite loops

// Combinational square calculation
wire [15:0] y_squared;
assign y_squared = y * y;

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        state <= IDLE;
        done <= 1'b0;
        result <= 16'd0;
        max_val <= 16'sd0;
        current_index <= 3'd0;
        current_val <= 16'sd0;
        y <= 8'd0;
        checking <= 1'b0;
    end else begin
        case (state)
            IDLE: begin
                done <= 1'b0;
                if (start) begin
                    state <= INIT;
                end
            end
            
            INIT: begin
                // Initialize max_val to minimum possible value
                // Since we're looking for largest non-square, start very low
                max_val <= 16'sd32768;  // Smallest 16-bit signed value
                current_index <= 3'd0;
                current_val <= arr_0;  // Load first element
                y <= 8'd0;
                checking <= 1'b1;
                state <= CHECK;
            end
            
            CHECK: begin
                if (!checking) begin
                    // Start checking a new number
                    y <= 8'd0;
                    checking <= 1'b1;
                end else begin
                    // Check if current_val is negative (not a perfect square)
                    if (current_val[15]) begin
                        state <= UPDATE;
                        checking <= 1'b0;
                    end else begin
                        // Check if y*y equals current_val
                        if (y_squared == current_val[15:0]) begin
                            // It's a perfect square, skip it
                            state <= NEXT;
                            checking <= 1'b0;
                        end else if (y_squared > current_val[15:0]) begin
                            // Exceeded current_val without matching - not a square
                            state <= UPDATE;
                            checking <= 1'b0;
                        end else begin
                            // Continue checking with next y
                            // Prevent infinite loop (max y for 16-bit is 255)
                            if (y < 8'd255) begin
                                y <= y + 8'd1;
                            end else begin
                                // Timeout - treat as non-square
                                state <= UPDATE;
                                checking <= 1'b0;
                            end
                        end
                    end
                end
            end
            
            UPDATE: begin
                // Update max_val if current_val is larger
                if ($signed(current_val) > $signed(max_val)) begin
                    max_val <= current_val;
                end
                state <= NEXT;
            end
            
            NEXT: begin
                if (current_index < 3'd7) begin
                    current_index <= current_index + 3'd1;
                    // Load next element based on index
                    case (current_index + 3'd1)
                        3'd0: current_val <= arr_0;
                        3'd1: current_val <= arr_1;
                        3'd2: current_val <= arr_2;
                        3'd3: current_val <= arr_3;
                        3'd4: current_val <= arr_4;
                        3'd5: current_val <= arr_5;
                        3'd6: current_val <= arr_6;
                        3'd7: current_val <= arr_7;
                        default: current_val <= arr_7;
                    endcase;
                    y <= 8'd0;
                    checking <= 1'b1;
                    state <= CHECK;
                end else begin
                    state <= DONE;
                end
            end
            
            DONE: begin
                result <= max_val[15:0];
                done <= 1'b1;
                state <= IDLE;
            end
            
            default: begin
                state <= IDLE;
                done <= 1'b0;
            end
        endcase
    end
end

endmodule