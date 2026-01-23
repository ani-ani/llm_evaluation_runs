module newman_shanks_williams (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [3:0] n,
    output reg [15:0] result,
    output reg done
);

    // State declarations
    localparam [1:0] IDLE    = 2'd0;
    localparam [1:0] COMPUTE = 2'd1;
    localparam [1:0] FINISH  = 2'd2;
    
    reg [1:0] state;
    reg [15:0] ns_prev;   // NS(n-2)
    reg [15:0] ns_curr;   // NS(n-1) / current result
    reg [3:0] counter;    // iteration counter
    localparam [3:0] MAX_CYCLES = 4'd10;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 16'd0;
            done <= 1'b0;
            ns_prev <= 16'd0;
            ns_curr <= 16'd0;
            counter <= 4'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    counter <= 4'd0;
                    if (start) begin
                        if (n == 4'd0 || n == 4'd1) begin
                            result <= 16'd1;
                            done <= 1'b1;
                            state <= IDLE;
                        end else begin
                            ns_prev <= 16'd1;  // NS(0)
                            ns_curr <= 16'd1;  // NS(1)
                            counter <= 4'd2;   // Start from iteration 2
                            state <= COMPUTE;
                        end
                    end
                end
                
                COMPUTE: begin
                    counter <= counter + 4'd1;
                    
                    // NS(i) = 2*NS(i-1) + NS(i-2)
                    ns_prev <= ns_curr;
                    ns_curr <= (ns_curr << 1) + ns_prev;
                    
                    // Exit conditions
                    if (counter >= n || counter >= MAX_CYCLES) begin
                        state <= FINISH;
                    end
                end
                
                FINISH: begin
                    result <= (ns_curr << 1) + ns_prev;
                    done <= 1'b1;
                    state <= IDLE;
                end
                
                default: state <= IDLE;
            endcase
        end
    end
endmodule