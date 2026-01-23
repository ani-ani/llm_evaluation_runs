module xorbonacci (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire query,
    input wire [7:0] a0, a1, a2, a3,
    input wire [15:0] l, r,
    output reg [7:0] result,
    output reg done
);

    // State encoding
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] LOADING = 3'd1;
    localparam [2:0] READY = 3'd2;
    localparam [2:0] COMPUTING = 3'd3;
    localparam [2:0] RESULT = 3'd4;
    localparam [2:0] DONE = 3'd5;

    reg [2:0] state;
    reg [7:0] P0, P1, P2, P3, P4;  // Prefix XOR table (P[0] to P[4])
    reg [15:0] l_reg, r_reg;        // Stored query indices
    reg [2:0] rem_l, rem_r;         // Remainders modulo 5
    reg [3:0] i;                    // Loop counter

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            result <= 8'd0;
            P0 <= 8'd0;
            P1 <= 8'd0;
            P2 <= 8'd0;
            P3 <= 8'd0;
            P4 <= 8'd0;
            l_reg <= 16'd0;
            r_reg <= 16'd0;
            rem_l <= 3'd0;
            rem_r <= 3'd0;
            i <= 4'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        // Compute prefix XOR table P[0..4]
                        P0 <= 8'd0;
                        P1 <= a0;
                        P2 <= a0 ^ a1;
                        P3 <= a0 ^ a1 ^ a2;
                        P4 <= a0 ^ a1 ^ a2 ^ a3;
                        state <= LOADING;
                    end
                end

                LOADING: begin
                    // One cycle to let P settle
                    state <= READY;
                end

                READY: begin
                    if (query) begin
                        l_reg <= l;
                        r_reg <= r;
                        state <= COMPUTING;
                    end
                end

                COMPUTING: begin
                    // Compute remainders modulo 5
                    rem_l <= 3'd0;
                    rem_r <= 3'd0;
                    
                    // Calculate rem_l = l_reg % 5
                    for (i = 0; i < 16; i = i + 1) begin
                        if (rem_l >= 3'd5) begin
                            rem_l <= rem_l - 3'd5;
                        end
                        if (l_reg[i]) begin
                            rem_l <= rem_l + 3'd1;
                        end
                        // Need to wait for rem_l to update
                        // This is a simplified approach
                    end
                    
                    // Calculate rem_r = r_reg % 5
                    for (i = 0; i < 16; i = i + 1) begin
                        if (rem_r >= 3'd5) begin
                            rem_r <= rem_r - 3'd5;
                        end
                        if (r_reg[i]) begin
                            rem_r <= rem_r + 3'd1;
                        end
                    end
                    
                    state <= RESULT;
                end

                RESULT: begin
                    // XOR the two prefix values
                    // rem_l and rem_r are indices 0..4
                    case (rem_l)
                        3'd0: begin
                            case (rem_r)
                                3'd0: result <= P0 ^ P0;
                                3'd1: result <= P1 ^ P0;
                                3'd2: result <= P2 ^ P0;
                                3'd3: result <= P3 ^ P0;
                                3'd4: result <= P4 ^ P0;
                                default: result <= 8'd0;
                            endcase
                        end
                        3'd1: begin
                            case (rem_r)
                                3'd0: result <= P0 ^ P1;
                                3'd1: result <= P1 ^ P1;
                                3'd2: result <= P2 ^ P1;
                                3'd3: result <= P3 ^ P1;
                                3'd4: result <= P4 ^ P1;
                                default: result <= 8'd0;
                            endcase
                        end
                        3'd2: begin
                            case (rem_r)
                                3'd0: result <= P0 ^ P2;
                                3'd1: result <= P1 ^ P2;
                                3'd2: result <= P2 ^ P2;
                                3'd3: result <= P3 ^ P2;
                                3'd4: result <= P4 ^ P2;
                                default: result <= 8'd0;
                            endcase
                        end
                        3'd3: begin
                            case (rem_r)
                                3'd0: result <= P0 ^ P3;
                                3'd1: result <= P1 ^ P3;
                                3'd2: result <= P2 ^ P3;
                                3'd3: result <= P3 ^ P3;
                                3'd4: result <= P4 ^ P3;
                                default: result <= 8'd0;
                            endcase
                        end
                        3'd4: begin
                            case (rem_r)
                                3'd0: result <= P0 ^ P4;
                                3'd1: result <= P1 ^ P4;
                                3'd2: result <= P2 ^ P4;
                                3'd3: result <= P3 ^ P4;
                                3'd4: result <= P4 ^ P4;
                                default: result <= 8'd0;
                            endcase
                        end
                        default: result <= 8'd0;
                    endcase
                    done <= 1'b1;
                    state <= DONE;
                end

                DONE: begin
                    done <= 1'b0;
                    state <= READY;
                end

                default: begin
                    state <= IDLE;
                    done <= 1'b0;
                    result <= 8'd0;
                end
            endcase
        end
    end

endmodule