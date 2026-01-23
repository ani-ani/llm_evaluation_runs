module salary_damage_calculator(
    input clk,
    input rst_n,
    input start,
    input [31:0] L0, R0,
    input [31:0] L1, R1,
    input [31:0] L2, R2,
    input [31:0] L3, R3,
    output reg [31:0] result,
    output reg done
);

    // State definition
    localparam IDLE = 3'b000;
    localparam CALCE = 3'b001;
    localparam CALCSUM = 3'b010;
    localparam DIVIDE = 3'b011;
    localparam DONE = 3'b100;

    reg [2:0] state, next_state;
    
    // Internal registers
    reg [31:0] E0, E1, E2, E3;
    reg [31:0] sum;
    reg [2:0] calc_index; // Counter for loops
    
    // State transition
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
        end else begin
            state <= next_state;
        end
    end
    
    // Next state logic
    always @(*) begin
        case (state)
            IDLE: begin
                if (start)
                    next_state = CALCE;
                else
                    next_state = IDLE;
            end
            CALCE: begin
                // E0, E1, E2, E3 calculation takes 4 cycles if sequential
                // Or combine states. Let's use calc_index to count 4 cycles
                if (calc_index == 3'b100) // 4 cycles done (0,1,2,3)
                    next_state = CALCSUM;
                else
                    next_state = CALCE;
            end
            CALCSUM: begin
                // Sum calculation: E1-E0, E2-E0, E3-E0, E2-E1, E3-E1, E3-E2 (6 pairs)
                if (calc_index == 3'b110) // 6 pairs done (indices 0-5)
                    next_state = DIVIDE;
                else
                    next_state = CALCSUM;
            end
            DIVIDE: begin
                next_state = DONE;
            end
            DONE: begin
                if (!start) // Wait for start to go low before accepting new start
                    next_state = IDLE;
                else
                    next_state = DONE;
            end
            default: next_state = IDLE;
        endcase
    end
    
    // Datapath logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            result <= 32'b0;
            done <= 1'b0;
            E0 <= 32'b0; E1 <= 32'b0; E2 <= 32'b0; E3 <= 32'b0;
            sum <= 32'b0;
            calc_index <= 3'b0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    calc_index <= 3'b0;
                    sum <= 32'b0;
                end
                
                CALCE: begin
                    // Calculate E[i] = (L[i] + R[i]) / 2
                    // Right shift by 1 for division by 2
                    case (calc_index)
                        3'b000: begin
                            E0 <= (L0 + R0) >> 1;
                            calc_index <= calc_index + 1;
                        end
                        3'b001: begin
                            E1 <= (L1 + R1) >> 1;
                            calc_index <= calc_index + 1;
                        end
                        3'b010: begin
                            E2 <= (L2 + R2) >> 1;
                            calc_index <= calc_index + 1;
                        end
                        3'b011: begin
                            E3 <= (L3 + R3) >> 1;
                            calc_index <= calc_index + 1;
                        end
                        default: calc_index <= calc_index + 1;
                    endcase
                end
                
                CALCSUM: begin
                    // Sum = sum + E[j] - E[i]
                    // Pairs: (0,1), (0,2), (0,3), (1,2), (1,3), (2,3)
                    case (calc_index)
                        3'b000: begin // (0,1)
                            sum <= sum + E1 - E0;
                            calc_index <= calc_index + 1;
                        end
                        3'b001: begin // (0,2)
                            sum <= sum + E2 - E0;
                            calc_index <= calc_index + 1;
                        end
                        3'b010: begin // (0,3)
                            sum <= sum + E3 - E0;
                            calc_index <= calc_index + 1;
                        end
                        3'b011: begin // (1,2)
                            sum <= sum + E2 - E1;
                            calc_index <= calc_index + 1;
                        end
                        3'b100: begin // (1,3)
                            sum <= sum + E3 - E1;
                            calc_index <= calc_index + 1;
                        end
                        3'b101: begin // (2,3)
                            sum <= sum + E3 - E2;
                            calc_index <= calc_index + 1;
                        end
                        default: calc_index <= calc_index + 1;
                    endcase
                end
                
                DIVIDE: begin
                    // Divide by 16 (N^2) using right shift by 4
                    result <= sum >>> 4;
                end
                
                DONE: begin
                    done <= 1'b1;
                end
            endcase
        end
    end

endmodule