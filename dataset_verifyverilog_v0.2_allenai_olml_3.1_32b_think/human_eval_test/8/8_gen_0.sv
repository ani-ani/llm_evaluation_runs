module sum_product (
    input clk,
    input rst_n, // active low
    input start,
    input [4:0] array_len,
    input [15:0] array_data [0:15],
    output reg [31:0] sum_out,
    output reg [31:0] product_out,
    output reg done
);

reg [31:0] sum;
reg [31:0] product;
reg [3:0] index;
reg [2:0] state;
reg done_delay;

// State definitions
localparam IDLE = 3'b0;
localparam PROCESSING = 3'b1;
localparam DONE = 3'b2;

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        // Reset: go to IDLE, sum=0, product=1, index=0, state=IDLE, done_delay=0
        state <= IDLE;
        sum <= 32'd0;
        product <= 32'd1;
        index <= 4'd0;
        done_delay <= 1'b0;
    end else begin
        done_delay <= 1'b0; // Default

        case(state)
            IDLE: begin
                if (start) begin
                    if (array_len == 0) begin
                        // Transition to DONE with delay
                        state <= DONE;
                        sum <= 32'd0;
                        product <= 32'd1;
                        done_delay <= 1'b1;
                    end else begin
                        // Start processing
                        state <= PROCESSING;
                        index <= 4'd0;
                        sum <= 32'd0;
                        product <= 32'd1;
                    end
                end else begin
                    // Stay in IDLE
                    state <= IDLE;
                end
            end
            PROCESSING: begin
                if (index == array_len) begin
                    // Move to DONE, no delay
                    state <= DONE;
                    done_delay <= 1'b0;
                end else begin
                    // Accumulate sum and product
                    sum <= sum + array_data[index];
                    product <= product * array_data[index];
                    index <= index + 1;
                    state <= PROCESSING;
                end
            end
            DONE: begin
                // Stay in DONE, ensure done_delay is 0
                state <= DONE;
                done_delay <= 1'b0;
            end
        endcase
    end
end

// Outputs
assign sum_out = sum;
assign product_out = product;
assign done = (state == DONE) && !done_delay;

endmodule