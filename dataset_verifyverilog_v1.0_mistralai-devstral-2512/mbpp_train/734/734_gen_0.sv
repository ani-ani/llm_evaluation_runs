module sum_of_subarray_products(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [7:0] arr_0,
    input wire [7:0] arr_1,
    input wire [7:0] arr_2,
    input wire [2:0] len,
    output reg [31:0] result,
    output reg done
);

    // State definitions
    localparam [1:0] IDLE    = 2'd0;
    localparam [1:0] LOAD    = 2'd1;
    localparam [1:0] COMPUTE = 2'd2;
    localparam [1:0] DONE    = 2'd3;

    // Internal registers
    reg [1:0] state;
    reg [1:0] idx;           // Index for computation (counts down)
    reg [31:0] res;          // Running product sum
    reg [31:0] ans;          // Accumulated result
    reg [7:0] internal_arr [0:2];  // Internal array storage

    // Multiplication result (40-bit to avoid overflow)
    wire [39:0] mult_result;
    assign mult_result = {24'd0, internal_arr[idx]} * {8'd0, res + 32'd1};

    // State machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Reset all registers
            state <= IDLE;
            idx <= 2'd0;
            res <= 32'd0;
            ans <= 32'd0;
            result <= 32'd0;
            done <= 1'b0;
            internal_arr[0] <= 8'd0;
            internal_arr[1] <= 8'd0;
            internal_arr[2] <= 8'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        state <= LOAD;
                    end
                end

                LOAD: begin
                    // Load input array into internal storage
                    internal_arr[0] <= arr_0;
                    internal_arr[1] <= arr_1;
                    internal_arr[2] <= arr_2;
                    
                    // Initialize computation variables
                    idx <= len - 3'd1;  // Start from len-1
                    res <= 32'd0;
                    ans <= 32'd0;
                    
                    // If len == 0, go directly to DONE
                    if (len == 3'd0) begin
                        state <= DONE;
                    end else begin
                        state <= COMPUTE;
                    end
                end

                COMPUTE: begin
                    // Compute temp = arr[idx] * (1 + res)
                    // Update ans = ans + temp
                    // Update res = temp
                    ans <= ans + mult_result[31:0];
                    res <= mult_result[31:0];
                    
                    // Decrement index
                    if (idx == 3'd0) begin
                        idx <= 3'd0;  // Stay at 0 for next state
                        state <= DONE;
                    end else begin
                        idx <= idx - 3'd1;
                    end
                end

                DONE: begin
                    result <= ans;
                    done <= 1'b1;
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end

endmodule