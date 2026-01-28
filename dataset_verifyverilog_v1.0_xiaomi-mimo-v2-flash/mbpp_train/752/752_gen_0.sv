module JacobsthalDP (
    input clk,
    input rst_n,
    input start,
    input [3:0] n,
    output reg [15:0] result,
    output reg done
);

    // State declarations
    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] COMPUTE = 2'd1;
    localparam [1:0] FINISH = 2'd2;
    
    reg [1:0] state, next_state;
    reg [3:0] n_reg;
    reg [3:0] counter;
    reg [15:0] j_prev, j_curr;
    reg [15:0] new_j;
    
    // State transition logic
    always @(*) begin
        case (state)
            IDLE: begin
                if (start && (n == 4'd0 || n == 4'd1)) begin
                    next_state = FINISH;
                end else if (start && n >= 4'd2) begin
                    next_state = COMPUTE;
                end else begin
                    next_state = IDLE;
                end
            end
            COMPUTE: begin
                if (counter == n_reg - 4'd1) begin
                    next_state = FINISH;
                end else begin
                    next_state = COMPUTE;
                end
            end
            FINISH: begin
                next_state = IDLE;
            end
            default: next_state = IDLE;
        endcase
    end

    // Sequential logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 16'd0;
            done <= 1'b0;
            n_reg <= 4'd0;
            counter <= 4'd0;
            j_prev <= 16'd0;
            j_curr <= 16'd0;
            new_j <= 16'd0;
        end else begin
            state <= next_state;
            
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    counter <= 4'd0;
                    if (start) begin
                        n_reg <= n;
                        if (n == 4'd0) begin
                            result <= 16'd0;
                        end else if (n == 4'd1) begin
                            result <= 16'd1;
                        end else begin
                            j_prev <= 16'd0;  // J(0)
                            j_curr <= 16'd1;  // J(1)
                        end
                    end
                end
                COMPUTE: begin
                    counter <= counter + 4'd1;
                    // new_j = j_curr + 2*j_prev
                    new_j <= j_curr + (j_prev << 1);
                    j_prev <= j_curr;
                    j_curr <= j_curr + (j_prev << 1);
                    
                    if (counter == n_reg - 4'd2) begin
                        result <= j_curr + (j_prev << 1);
                    end
                end
                FINISH: begin
                    done <= 1'b1;
                end
                default: begin
                    state <= IDLE;
                    done <= 1'b0;
                end
            endcase
        end
    end

endmodule