module CardGameThree(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [3:0] n_val,
    input wire [3:0] m_val,
    input wire [3:0] k_val,
    input wire [15:0] card_a,
    input wire [15:0] card_b,
    input wire [15:0] card_c,
    output reg [31:0] result,
    output reg done
);

    // State declarations
    localparam [2:0] IDLE      = 3'd0;
    localparam [2:0] INIT      = 3'd1;
    localparam [2:0] SIMULATE  = 3'd2;
    localparam [2:0] COUNT     = 3'd3;
    localparam [2:0] FINISH    = 3'd4;

    // Game state
    reg [2:0] state;
    reg [2:0] next_state;

    // Counters and indices
    reg [3:0] a_idx;
    reg [3:0] b_idx;
    reg [3:0] c_idx;
    reg [2:0] current_player;
    reg [3:0] config_counter;
    reg [3:0] cycle_count;
    reg [3:0] max_cycles;

    // Winner tracking
    reg alice_wins;
    reg [31:0] win_count;

    // Constants
    localparam [31:0] MODULUS = 32'd1000000007;
    localparam [3:0] MAX_CYCLES = 4'd16;

    // State machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 32'd0;
            done <= 1'b0;
            win_count <= 32'd0;
            config_counter <= 4'd0;
            cycle_count <= 4'd0;
            a_idx <= 4'd0;
            b_idx <= 4'd0;
            c_idx <= 4'd0;
            current_player <= 2'd0;
            alice_wins <= 1'b0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        state <= INIT;
                    end
                end

                INIT: begin
                    win_count <= 32'd0;
                    config_counter <= 4'd0;
                    max_cycles <= n_val + m_val + k_val;
                    state <= SIMULATE;
                end

                SIMULATE: begin
                    // Reset game state for new configuration
                    if (config_counter == 4'd0) begin
                        a_idx <= 4'd0;
                        b_idx <= 4'd0;
                        c_idx <= 4'd0;
                        current_player <= 2'd0;
                        alice_wins <= 1'b0;
                        cycle_count <= 4'd0;
                    end

                    // Game simulation
                    if (cycle_count < max_cycles) begin
                        case (current_player)
                            2'd0: begin // Alice
                                if (a_idx < n_val) begin
                                    case (card_a[a_idx])
                                        2'd0: current_player <= 2'd0; // a -> Alice
                                        2'd1: current_player <= 2'd1; // b -> Bob
                                        2'd2: current_player <= 2'd2; // c -> Charlie
                                        default: current_player <= 2'd0;
                                    endcase
                                    a_idx <= a_idx + 4'd1;
                                end else begin
                                    alice_wins <= 1'b1;
                                end
                            end

                            2'd1: begin // Bob
                                if (b_idx < m_val) begin
                                    case (card_b[b_idx])
                                        2'd0: current_player <= 2'd0; // a -> Alice
                                        2'd1: current_player <= 2'd1; // b -> Bob
                                        2'd2: current_player <= 2'd2; // c -> Charlie
                                        default: current_player <= 2'd0;
                                    endcase
                                    b_idx <= b_idx + 4'd1;
                                end else begin
                                    alice_wins <= 1'b0;
                                end
                            end

                            2'd2: begin // Charlie
                                if (c_idx < k_val) begin
                                    case (card_c[c_idx])
                                        2'd0: current_player <= 2'd0; // a -> Alice
                                        2'd1: current_player <= 2'd1; // b -> Bob
                                        2'd2: current_player <= 2'd2; // c -> Charlie
                                        default: current_player <= 2'd0;
                                    endcase
                                    c_idx <= c_idx + 4'd1;
                                end else begin
                                    alice_wins <= 1'b0;
                                end
                            end

                            default: current_player <= 2'd0;
                        endcase

                        cycle_count <= cycle_count + 4'd1;

                        // Check if simulation is complete
                        if (cycle_count >= max_cycles || 
                            (a_idx >= n_val && b_idx >= m_val && c_idx >= k_val)) begin
                            state <= COUNT;
                        end
                    end else begin
                        state <= COUNT;
                    end
                end

                COUNT: begin
                    if (alice_wins) begin
                        win_count <= (win_count + 32'd1) % MODULUS;
                    end

                    // Move to next configuration
                    config_counter <= config_counter + 4'd1;

                    // Check if all configurations are processed
                    if (config_counter >= 4'd16) begin
                        state <= FINISH;
                    end else begin
                        state <= SIMULATE;
                    end
                end

                FINISH: begin
                    result <= win_count;
                    done <= 1'b1;
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end

endmodule