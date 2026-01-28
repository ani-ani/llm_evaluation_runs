module shanks_williams_counter (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [3:0] n,
    output reg [15:0] result,
    output reg done
);

// State declarations
localparam [1:0] IDLE = 2'd0;
localparam [1:0] INIT = 2'd1;
localparam [1:0] COMPUTE = 2'd2;
localparam [1:0] FINISH = 2'd3;

reg [1:0] state, next_state;
reg [15:0] ns_prev;   // NS(n-2)
reg [15:0] ns_curr;   // NS(n-1) / current result
reg [3:0] counter;    // iteration counter
reg [3:0] target_n;   // store target n

// State transition logic
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        state <= IDLE;
        result <= 16'd0;
        done <= 1'b0;
        ns_prev <= 16'd0;
        ns_curr <= 16'd0;
        counter <= 4'd0;
        target_n <= 4'd0;
    end else begin
        case (state)
            IDLE: begin
                done <= 1'b0;
                if (start) begin
                    state <= INIT;
                end
            end
            
            INIT: begin
                // Base cases
                if (n == 4'd0) begin
                    result <= 16'd1;
                    state <= FINISH;
                end else if (n == 4'd1) begin
                    result <= 16'd1;
                    state <= FINISH;
                end else begin
                    // n >= 2
                    ns_prev <= 16'd1;  // NS(0)
                    ns_curr <= 16'd1;  // NS(1)
                    counter <= 4'd2;
                    target_n <= n;
                    state <= COMPUTE;
                end
            end
            
            COMPUTE: begin
                // NS(i) = 2*NS(i-1) + NS(i-2)
                ns_prev <= ns_curr;
                ns_curr <= (ns_curr << 1) + ns_prev;
                counter <= counter + 1'b1;
                
                if (counter + 1'b1 >= target_n) begin
                    state <= FINISH;
                end
            end
            
            FINISH: begin
                done <= 1'b1;
                result <= (ns_curr << 1) + ns_prev;
                state <= IDLE;
            end
            
            default: state <= IDLE;
        endcase
    end
end

endmodule