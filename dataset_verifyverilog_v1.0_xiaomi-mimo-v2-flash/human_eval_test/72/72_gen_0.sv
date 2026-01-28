module will_it_fly (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [7:0] q [0:15],
    input wire [3:0] len,
    input wire [15:0] w,
    output reg result,
    output reg done
);

    // State declarations
    localparam [2:0] IDLE      = 3'd0;
    localparam [2:0] LOAD      = 3'd1;
    localparam [2:0] CHECK_PAL = 3'd2;
    localparam [2:0] CALC_SUM  = 3'd3;
    localparam [2:0] COMPARE   = 3'd4;
    localparam [2:0] FINISH    = 3'd5;

    // Internal registers
    reg [2:0] state;
    reg [3:0] i;              // Loop counter (0 to 15)
    reg [15:0] sum_reg;       // Accumulated sum
    reg is_palindrome_reg;    // Palindrome check result
    reg [7:0] q_reg [0:15];   // Local copy of input array
    reg [3:0] len_reg;        // Local copy of length
    reg [15:0] w_reg;         // Local copy of weight limit
    reg [7:0] temp_left;      // Temporary storage for comparison
    reg [7:0] temp_right;     // Temporary storage for comparison
    reg [7:0] cycle_count;    // Prevent infinite loops
    localparam [7:0] MAX_CYCLES = 8'd100;

    // Control signals
    reg start_dly;
    wire start_pulse;
    assign start_pulse = start && !start_dly;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Reset all registers
            state <= IDLE;
            result <= 1'b0;
            done <= 1'b0;
            i <= 4'd0;
            sum_reg <= 16'd0;
            is_palindrome_reg <= 1'b1;
            len_reg <= 4'd0;
            w_reg <= 16'd0;
            temp_left <= 8'd0;
            temp_right <= 8'd0;
            cycle_count <= 8'd0;
            start_dly <= 1'b0;
            // Initialize array
            for (int idx = 0; idx < 16; idx = idx + 1) begin
                q_reg[idx] <= 8'd0;
            end
        end else begin
            start_dly <= start;
            
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    is_palindrome_reg <= 1'b1;
                    sum_reg <= 16'd0;
                    i <= 4'd0;
                    cycle_count <= 8'd0;
                    
                    if (start_pulse) begin
                        state <= LOAD;
                    end
                end
                
                LOAD: begin
                    // Load inputs to local registers
                    len_reg <= len;
                    w_reg <= w;
                    
                    // Copy array elements
                    // Since we can't use array slice assignment, copy individually
                    q_reg[0] <= q[0];
                    q_reg[1] <= q[1];
                    q_reg[2] <= q[2];
                    q_reg[3] <= q[3];
                    q_reg[4] <= q[4];
                    q_reg[5] <= q[5];
                    q_reg[6] <= q[6];
                    q_reg[7] <= q[7];
                    q_reg[8] <= q[8];
                    q_reg[9] <= q[9];
                    q_reg[10] <= q[10];
                    q_reg[11] <= q[11];
                    q_reg[12] <= q[12];
                    q_reg[13] <= q[13];
                    q_reg[14] <= q[14];
                    q_reg[15] <= q[15];
                    
                    i <= 4'd0;
                    cycle_count <= cycle_count + 8'd1;
                    
                    // Check for single element or zero length
                    if (len <= 4'd1) begin
                        state <= CALC_SUM;
                    end else begin
                        state <= CHECK_PAL;
                    end
                end
                
                CHECK_PAL: begin
                    cycle_count <= cycle_count + 8'd1;
                    
                    // Get comparison values
                    temp_left <= q_reg[i];
                    temp_right <= q_reg[len_reg - 1 - i];
                    
                    // Compare and update palindrome status
                    if (q_reg[i] != q_reg[len_reg - 1 - i]) begin
                        is_palindrome_reg <= 1'b0;
                    end
                    
                    // Increment counter
                    i <= i + 4'd1;
                    
                    // Check if done comparing
                    // We need to compare i from 0 to floor((len-1)/2)
                    // So compare while i < (len/2)
                    if ((len_reg >= 4'd2) && (i + 4'd1 >= len_reg[3:1])) begin
                        state <= CALC_SUM;
                        i <= 4'd0;
                    end else if (cycle_count >= MAX_CYCLES) begin
                        // Safety timeout
                        state <= FINISH;
                        result <= 1'b0;
                        done <= 1'b1;
                    end
                end
                
                CALC_SUM: begin
                    cycle_count <= cycle_count + 8'd1;
                    
                    // Accumulate sum
                    sum_reg <= sum_reg + {8'd0, q_reg[i]};
                    
                    // Increment counter
                    i <= i + 4'd1;
                    
                    // Check if done summing
                    if (i >= len_reg - 4'd1) begin
                        state <= COMPARE;
                    end else if (cycle_count >= MAX_CYCLES) begin
                        // Safety timeout
                        state <= FINISH;
                        result <= 1'b0;
                        done <= 1'b1;
                    end
                end
                
                COMPARE: begin
                    cycle_count <= cycle_count + 8'd1;
                    
                    // Compare sum with weight limit
                    result <= (is_palindrome_reg && (sum_reg <= w_reg));
                    
                    state <= FINISH;
                end
                
                FINISH: begin
                    done <= 1'b1;
                    state <= IDLE;
                end
                
                default: begin
                    state <= IDLE;
                    result <= 1'b0;
                    done <= 1'b0;
                end
            endcase
        end
    end

endmodule