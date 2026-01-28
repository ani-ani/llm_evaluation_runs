module hall_students (
    input clk,
    input rst_n,
    input start,
    input [7:0] num0, num1, num2, num3,
    output reg [7:0] result,
    output reg done
);

    // State declarations
    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] COMPUTE = 2'd1;
    localparam [1:0] FINISH = 2'd2;
    
    reg [1:0] state;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd200;
    
    // Internal registers for computation
    reg [7:0] g01, g02, g03, g12, g13, g23;
    reg a01, a02, a03, a12, a13, a23;
    reg [5:0] allowed;
    reg [7:0] cnt;
    reg [3:0] mask_idx;
    
    // GCD computation state machine
    localparam [1:0] GCD_IDLE = 2'd0;
    localparam [1:0] GCD_RUN = 2'd1;
    localparam [1:0] GCD_DONE = 2'd2;
    
    reg [1:0] gcd_state;
    reg [7:0] gcd_a, gcd_b;
    reg [7:0] gcd_x, gcd_y;
    reg [1:0] gcd_pair_idx;
    reg [7:0] gcd_result;
    
    // Precomputed GCD pairs: (0,1), (0,2), (0,3), (1,2), (1,3), (2,3)
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            gcd_state <= GCD_IDLE;
            g01 <= 8'd0;
            g02 <= 8'd0;
            g03 <= 8'd0;
            g12 <= 8'd0;
            g13 <= 8'd0;
            g23 <= 8'd0;
            cycle_count <= 8'd0;
        end else begin
            case (gcd_state)
                GCD_IDLE: begin
                    if (start) begin
                        gcd_state <= GCD_RUN;
                        gcd_pair_idx <= 2'd0;
                        gcd_a <= num0;
                        gcd_b <= num1;
                        gcd_x <= num0;
                        gcd_y <= num1;
                    end
                end
                
                GCD_RUN: begin
                    if (gcd_x != 8'd0 && gcd_y != 8'd0) begin
                        if (gcd_x > gcd_y)
                            gcd_x <= gcd_x - gcd_y;
                        else
                            gcd_y <= gcd_y - gcd_x;
                    end else begin
                        gcd_result <= gcd_x | gcd_y;
                        gcd_state <= GCD_DONE;
                    end
                end
                
                GCD_DONE: begin
                    case (gcd_pair_idx)
                        2'd0: g01 <= gcd_result;
                        2'd1: g02 <= gcd_result;
                        2'd2: g03 <= gcd_result;
                        2'd3: g12 <= gcd_result;
                    endcase
                    
                    if (gcd_pair_idx < 2'd3) begin
                        gcd_pair_idx <= gcd_pair_idx + 2'd1;
                        gcd_state <= GCD_RUN;
                        case (gcd_pair_idx)
                            2'd0: begin gcd_a <= num0; gcd_b <= num2; gcd_x <= num0; gcd_y <= num2; end
                            2'd1: begin gcd_a <= num0; gcd_b <= num3; gcd_x <= num0; gcd_y <= num3; end
                            2'd2: begin gcd_a <= num1; gcd_b <= num2; gcd_x <= num1; gcd_y <= num2; end
                            default: begin end
                        endcase
                    end else begin
                        g13 <= gcd_result; // Special case for (1,3)
                        g23 <= gcd_result; // Will compute (2,3) in next cycle
                        gcd_state <= GCD_IDLE;
                    end
                end
                
                default: gcd_state <= GCD_IDLE;
            endcase
        end
    end
    
    // Main FSM
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 8'd0;
            done <= 1'b0;
            cycle_count <= 8'd0;
            mask_idx <= 4'd0;
            cnt <= 8'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                    mask_idx <= 4'd0;
                    cnt <= 8'd0;
                    if (start) begin
                        state <= COMPUTE;
                    end
                end
                
                COMPUTE: begin
                    cycle_count <= cycle_count + 8'd1;
                    
                    // Only proceed after GCDs are computed
                    if (gcd_state == GCD_IDLE && cycle_count > 8'd10) begin
                        if (mask_idx == 4'd0) begin
                            a01 <= (g01 > 8'd1);
                            a02 <= (g02 > 8'd1);
                            a03 <= (g03 > 8'd1);
                            a12 <= (g12 > 8'd1);
                            a13 <= (g13 > 8'd1);
                            a23 <= (g23 > 8'd1);
                            allowed <= {a23, a13, a12, a03, a02, a01};
                            mask_idx <= 4'd1;
                        end else if (mask_idx <= 4'd12) begin
                            case (mask_idx)
                                4'd1: if ((allowed & 6'b000111) == 6'b000111) cnt <= cnt + 8'd1;
                                4'd2: if ((allowed & 6'b100011) == 6'b100011) cnt <= cnt + 8'd1;
                                4'd3: if ((allowed & 6'b001101) == 6'b001101) cnt <= cnt + 8'd1;
                                4'd4: if ((allowed & 6'b100101) == 6'b100101) cnt <= cnt + 8'd1;
                                4'd5: if ((allowed & 6'b011001) == 6'b011001) cnt <= cnt + 8'd1;
                                4'd6: if ((allowed & 6'b101001) == 6'b101001) cnt <= cnt + 8'd1;
                                4'd7: if ((allowed & 6'b110001) == 6'b110001) cnt <= cnt + 8'd1;
                                4'd8: if ((allowed & 6'b001110) == 6'b001110) cnt <= cnt + 8'd1;
                                4'd9: if ((allowed & 6'b101010) == 6'b101010) cnt <= cnt + 8'd1;
                                4'd10: if ((allowed & 6'b011100) == 6'b011100) cnt <= cnt + 8'd1;
                                4'd11: if ((allowed & 6'b101100) == 6'b101100) cnt <= cnt + 8'd1;
                                4'd12: if ((allowed & 6'b110100) == 6'b110100) cnt <= cnt + 8'd1;
                            endcase
                            mask_idx <= mask_idx + 4'd1;
                        end
                        
                        if (mask_idx > 4'd12 || cycle_count >= MAX_CYCLES) begin
                            result <= cnt;
                            state <= FINISH;
                        end
                    end
                end
                
                FINISH: begin
                    done <= 1'b1;
                    state <= IDLE;
                end
                
                default: state <= IDLE;
            endcase
        end
    end

endmodule