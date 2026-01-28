module add_elements (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire signed [15:0] arr [0:15],
    input wire [3:0] k,
    output reg signed [17:0] result,
    output reg done
);

    // State declarations
    localparam [1:0] IDLE       = 2'd0;
    localparam [1:0] PROCESSING = 2'd1;
    localparam [1:0] FINISHED   = 2'd2;

    // Internal registers
    reg [1:0] state;
    reg [3:0] counter;           // Current index (0 to k-1)
    reg [3:0] k_reg;             // Store k value during processing
    reg signed [17:0] sum_reg;   // Accumulated sum (18-bit signed)
    reg [6:0] cycle_count;       // Cycle counter (0-99)
    localparam [6:0] MAX_CYCLES = 7'd100;

    // Combinational logic for digit check
    // abs(value) < 100 means -99 <= value <= 99
    wire in_range;
    assign in_range = (arr[counter] >= -16'sd99) && (arr[counter] <= 16'sd99);

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Reset all registers
            state <= IDLE;
            result <= 18'sd0;
            done <= 1'b0;
            counter <= 4'd0;
            k_reg <= 4'd0;
            sum_reg <= 18'sd0;
            cycle_count <= 7'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    counter <= 4'd0;
                    cycle_count <= 7'd0;
                    sum_reg <= 18'sd0;
                    if (start) begin
                        k_reg <= k;
                        if (k > 4'd0) begin
                            state <= PROCESSING;
                        end else begin
                            // k = 0, no elements to process
                            result <= 18'sd0;
                            state <= FINISHED;
                        end
                    end
                end

                PROCESSING: begin
                    cycle_count <= cycle_count + 7'd1;
                    
                    // Check if current element is in range and add to sum
                    if (in_range) begin
                        sum_reg <= sum_reg + { {2{arr[counter][15]}}, arr[counter] };
                    end
                    
                    // Increment counter
                    counter <= counter + 4'd1;
                    
                    // Check completion conditions
                    if ((counter + 4'd1) >= k_reg || cycle_count >= MAX_CYCLES) begin
                        // Clamp result to 18-bit signed range
                        result <= sum_reg;
                        state <= FINISHED;
                    end
                end

                FINISHED: begin
                    done <= 1'b1;
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end

endmodule