module NudgemonXPOptimizer(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [4:0] config_addr,
    input wire [31:0] config_data,
    output reg [15:0] result,
    output reg done,
    output reg [3:0] debug_state
);

    // State definitions
    localparam [3:0] IDLE = 4'd0;
    localparam [3:0] LOAD_FAMILIES = 4'd1;
    localparam [3:0] LOAD_CATCHES = 4'd2;
    localparam [3:0] EVAL_EGG = 4'd3;
    localparam [3:0] PROCESS_CATCHES = 4'd4;
    localparam [3:0] GREEDY_EVOLVE = 4'd5;
    localparam [3:0] UPDATE_MAX = 4'd6;
    localparam [3:0] NEXT_EGG = 4'd7;
    localparam [3:0] DONE_STATE = 4'd8;

    // Configuration storage
    reg [7:0] family_ids [0:7];
    reg [7:0] family_costs [0:7][0:6];
    reg [7:0] family_sizes [0:7];
    reg [8:0] catch_times [0:63];
    reg [7:0] catch_ids [0:63];
    reg [5:0] num_catches;
    reg [2:0] num_families;

    // Computation registers
    reg [15:0] max_xp;
    reg [15:0] current_xp;
    reg [7:0] current_candies [0:7];
    reg [7:0] current_ranks [0:7];
    reg [5:0] egg_index;
    reg [5:0] catch_index;
    reg [5:0] family_index;
    reg [5:0] evolution_index;
    reg [8:0] window_start;
    reg [8:0] window_end;
    reg [8:0] current_time;
    reg in_window;
    reg can_evolve;

    // State machine
    reg [3:0] state;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 16'd0;
            done <= 1'b0;
            debug_state <= 4'd0;
            max_xp <= 16'd0;
            egg_index <= 6'd0;
            catch_index <= 6'd0;
            family_index <= 6'd0;
            evolution_index <= 6'd0;
            num_catches <= 6'd0;
            num_families <= 3'd0;

            // Initialize configuration storage
            integer i, j;
            for (i = 0; i < 8; i = i + 1) begin
                family_ids[i] <= 8'd0;
                family_sizes[i] <= 8'd0;
                current_candies[i] <= 8'd0;
                current_ranks[i] <= 8'd0;
                for (j = 0; j < 7; j = j + 1) begin
                    family_costs[i][j] <= 8'd0;
                end
            end
            for (i = 0; i < 64; i = i + 1) begin
                catch_times[i] <= 9'd0;
                catch_ids[i] <= 8'd0;
            end
        end else begin
            debug_state <= state;
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        state <= LOAD_FAMILIES;
                    end
                end

                LOAD_FAMILIES: begin
                    // Load family configuration
                    if (config_addr < 8) begin
                        // Store family ID and size
                        family_ids[config_addr] <= config_data[7:0];
                        family_sizes[config_addr] <= config_data[15:8];
                        // Store costs
                        family_costs[config_addr][0] <= config_data[23:16];
                        family_costs[config_addr][1] <= config_data[31:24];
                    end else if (config_addr < 16) begin
                        // Additional costs
                        reg [2:0] fam_idx = config_addr - 8;
                        reg [2:0] cost_idx = config_data[31:29];
                        if (cost_idx < 7) begin
                            family_costs[fam_idx][cost_idx + 2] <= config_data[23:16];
                        end
                    end else if (config_addr == 16) begin
                        num_families <= config_data[7:0];
                        state <= LOAD_CATCHES;
                    end
                end

                LOAD_CATCHES: begin
                    // Load catch data
                    if (config_addr < 80) begin
                        reg [5:0] catch_idx = config_addr - 20;
                        if (catch_idx < 64) begin
                            catch_times[catch_idx] <= config_data[8:0];
                            catch_ids[catch_idx] <= config_data[15:8];
                        end
                    end else if (config_addr == 80) begin
                        num_catches <= config_data[5:0];
                        state <= EVAL_EGG;
                        egg_index <= 6'd0;
                    end
                end

                EVAL_EGG: begin
                    // Initialize for new egg evaluation
                    current_xp <= 16'd0;
                    integer i;
                    for (i = 0; i < 8; i = i + 1) begin
                        current_candies[i] <= 8'd0;
                        current_ranks[i] <= 8'd0;
                    end

                    // Set window
                    if (egg_index < num_catches) begin
                        window_start <= catch_times[egg_index];
                        window_end <= catch_times[egg_index] + 9'd1800;
                    end else begin
                        window_start <= 9'd0;
                        window_end <= 9'd0;
                    end

                    catch_index <= 6'd0;
                    state <= PROCESS_CATCHES;
                end

                PROCESS_CATCHES: begin
                    if (catch_index < num_catches) begin
                        current_time <= catch_times[catch_index];
                        in_window <= (current_time >= window_start) && (current_time < window_end);

                        // Find family for this catch
                        integer i;
                        for (i = 0; i < num_families; i = i + 1) begin
                            if (family_ids[i] == catch_ids[catch_index]) begin
                                family_index <= i;
                                break;
                            end
                        end

                        // Process catch
                        if (!in_window) begin
                            // Transfer: gain 1 candy
                            current_candies[family_index] <= current_candies[family_index] + 8'd1;
                        end else begin
                            // Keep: gain 100 XP and 3 candies
                            current_xp <= current_xp + 16'd100;
                            current_candies[family_index] <= current_candies[family_index] + 8'd3;
                        end

                        catch_index <= catch_index + 6'd1;
                    end else begin
                        // All catches processed, start greedy evolution
                        catch_index <= 6'd0;
                        state <= GREEDY_EVOLVE;
                    end
                end

                GREEDY_EVOLVE: begin
                    if (catch_index < num_catches) begin
                        current_time <= catch_times[catch_index];
                        in_window <= (current_time >= window_start) && (current_time < window_end);

                        if (in_window) begin
                            // Find family for this catch
                            integer i;
                            for (i = 0; i < num_families; i = i + 1) begin
                                if (family_ids[i] == catch_ids[catch_index]) begin
                                    family_index <= i;
                                    break;
                                end
                            end

                            // Try to evolve as much as possible
                            evolution_index <= 6'd0;
                            state <= GREEDY_EVOLVE + 1;
                        end else begin
                            catch_index <= catch_index + 6'd1;
                        end
                    end else begin
                        // All catches processed, update max
                        state <= UPDATE_MAX;
                    end
                end

                GREEDY_EVOLVE + 1: begin
                    if (evolution_index < family_sizes[family_index] - 1) begin
                        // Check if we can evolve
                        if (current_candies[family_index] >= family_costs[family_index][evolution_index]) begin
                            // Evolve: gain 1000 XP (doubled), consume cost
                            current_xp <= current_xp + 16'd1000;
                            current_candies[family_index] <= current_candies[family_index] - family_costs[family_index][evolution_index];
                            current_ranks[family_index] <= current_ranks[family_index] + 8'd1;
                            evolution_index <= evolution_index + 6'd1;
                        end else begin
                            // Can't evolve further
                            catch_index <= catch_index + 6'd1;
                            state <= GREEDY_EVOLVE;
                        end
                    end else begin
                        // Already max rank
                        catch_index <= catch_index + 6'd1;
                        state <= GREEDY_EVOLVE;
                    end
                end

                UPDATE_MAX: begin
                    if (current_xp > max_xp) begin
                        max_xp <= current_xp;
                    end
                    state <= NEXT_EGG;
                end

                NEXT_EGG: begin
                    egg_index <= egg_index + 6'd1;
                    if (egg_index <= num_catches) begin
                        state <= EVAL_EGG;
                    end else begin
                        state <= DONE_STATE;
                    end
                end

                DONE_STATE: begin
                    result <= max_xp;
                    done <= 1'b1;
                    state <= IDLE;
                end

                default: begin
                    state <= IDLE;
                end
            endcase
        end
    end

endmodule