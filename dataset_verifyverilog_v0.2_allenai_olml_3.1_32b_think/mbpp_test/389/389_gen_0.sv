module lucas_number (
    input clk,
    input rst_n, // active-low reset
    input start,
    input [4:0] n,
    output reg [15:0] result,
    output reg done
);

// State definitions
localparam IDLE = 2'b00; // 0
INIT = 2'b01; //1
ITER = 2'b10; //2
DONE = 2'b11; //3

// Declare all registers
reg [1:0] state, next_state;
reg [15:0] prev, curr, next_prev, next_curr;
reg [5:0] counter, next_counter;
reg [15:0] internal_result, next_internal_result;
reg done, next_done;

// Assign outputs
assign result = next_internal_result;
assign done = next_done;

always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        state <= IDLE;
        next_state <= IDLE;
        prev <= 16'd0;
        curr <= 16'd0;
        next_prev <=16'd0;
        next_curr <=16'd0;
        counter <=5'd0;
        next_counter <=5'd0;
        internal_result <=16'd0;
        next_internal_result <=16'd0;
        done <=1'b0;
        next_done <=1'b0;
    end else begin
        state <= next_state;
        next_state <= state; // default hold
        prev <= next_prev;
        next_prev <= prev; // default hold
        curr <= next_curr;
        next_curr <= curr; // default hold
        counter <= next_counter;
        next_counter <= counter; // default hold
        internal_result <= next_internal_result;
        next_internal_result <= internal_result; // default hold
        done <= next_done;
        next_done <= done; // default hold
        // Now process state
        case(state)
            IDLE: begin
                if (start) begin
                    if (n ==0) begin
                        next_state <= DONE;
                        next_internal_result <= 2;
                        next_done <=1;
                    end else if (n ==1) begin
                        next_state <= DONE;
                        next_internal_result <=1;
                        next_done <=1;
                    end else begin // n>=2
                        next_state <= INIT;
                    end
                end
            end
            INIT: begin
                next_state <= ITER;
                next_prev <=2;
                next_curr <=1;
                next_counter <=2;
            end
            ITER: begin
                if (counter <= n) begin
                    next_prev <= curr;
                    next_curr <= prev + curr;
                    next_counter <= counter +1;
                    next_state <= ITER;
                end else begin
                    next_state <= DONE;
                    next_internal_result <= curr;
                    next_done <=1;
                end
            end
            DONE: begin
                next_state <= DONE;
            end
        endcase
    end
end

endmodule