module sum_of_subarray_products (
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
    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] LOAD = 2'd1;
    localparam [1:0] COMPUTE = 2'd2;
    localparam [1:0] DONE = 2'd3;

    // Internal registers
    reg [1:0] state;
    reg [2:0] idx;                 // Index counter for computation (len-1 downto 0)
    reg [31:0] res;                // Running sum of products starting from next index
    reg [31:0] ans;                // Accumulated total answer
    reg [31:0] buffer [0:2];       // Local buffer to hold input array
    reg [2:0] len_reg;             // Latched length

    // Multiplication temporary (width 32 bits is sufficient for max product < 2^32)
    wire [31:0] mult_result;
    // arr[i] is 8-bit, (1 + res) is up to 32-bit, product fits in 32-bit for len <= 3
    assign mult_result = buffer[idx[1:0]] * (32'd1 + res);

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 32'd0;
            done <= 1'b0;
            res <= 32'd0;
            ans <= 32'd0;
            idx <= 3'd0;
            len_reg <= 3'd0;
            buffer[0] <= 8'd0;
            buffer[1] <= 8'd0;
            buffer[2] <= 8'd0;
        end else begin
            done <= 1'b0; // Default done is 0
            case (state)
                IDLE: begin
                    if (start) begin
                        // Latch input array into buffer
                        buffer[0] <= arr_0;
                        buffer[1] <= arr_1;
                        buffer[2] <= arr_2;
                        len_reg <= len;
                        state <= LOAD;
                    end
                end

                LOAD: begin
                    // Determine start index and initialize registers
                    if (len_reg == 3'd0) begin
                        // No elements, output 0 immediately
                        result <= 32'd0;
                        done <= 1'b1;
                        state <= IDLE;
                    end else begin
                        // Start from last element (len-1)
                        idx <= len_reg - 3'd1;
                        res <= 32'd0;
                        ans <= 32'd0;
                        state <= COMPUTE;
                    end
                end

                COMPUTE: begin
                    // Perform: temp = arr[idx] * (1 + res)
                    // ans = ans + temp
                    // res = temp
                    ans <= ans + mult_result;
                    res <= mult_result;
                    
                    if (idx == 3'd0) begin
                        // Computation complete
                        result <= ans + mult_result;
                        done <= 1'b1;
                        state <= DONE;
                    end else begin
                        idx <= idx - 3'd1;
                    end
                end

                DONE: begin
                    // Done pulse is 1 cycle, return to IDLE
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end

endmodule