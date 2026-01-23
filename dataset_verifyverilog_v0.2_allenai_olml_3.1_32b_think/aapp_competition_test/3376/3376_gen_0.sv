module nudgemon_optimal_xp(input clk, input rst_n, input start, input [5:0] num_catches, input [5:0] num_families, input [31:0] catch_times [0:7], input [7:0] catch_family [0:7], input [3:0] family_evolution_cost [0:7], output reg [31:0] max_xp, output reg done);

// Internal registers
reg [31:0] captured_catch_times [0:7];
reg [5:0] captured_num_catches;
reg [5:0] captured_num_families;
reg [3:0] captured_ev_cost;
reg [31:0] window_starts [0:3];
reg [3:0] window_catches [0:3];
reg [31:0] max_xp_internal;
reg [2:0] state;

// State definitions
parameter IDLE = 3'd0, PARSE_INPUT=3'd1, EVALUATE_WINDOWS=3'd2, COMPUTE_XP=3'd3, WAIT_DELAY=3'd4, DONE=3'd5;

// Fixed-point constants
localparam XP_CATCH = 32'h00C80000;
localparam XP_EVOLUTION = 32'h03E80000;
localparam WINDOW_DURATION = 32'h07080000;

// Main state machine
always_ff @(posedge clk) begin
    if (!rst_n) begin
        captured_num_catches <= 8'd0;
        captured_num_families <= 8'd0;
        captured_ev_cost <= 4'd0;
        max_xp_internal <= 32'd0;
        state <= IDLE;
        max_xp <= 32'd0;
        done <= 1'b0;
        window_starts <= 32'd0;
        window_catches <= 4'd0;
    end else begin
        case (state)
            IDLE: if (start) state <= PARSE_INPUT; end
            PARSE_INPUT: begin
                captured_num_catches <= num_catches;
                captured_num_families <= num_families;
                if (captured_num_families > 0) captured_ev_cost <= family_evolution_cost[0];
                else captured_ev_cost <= 4'd0;
                window_starts[0] <= catch_times[0];
                for (int i=1; i<4; i++) window_starts[i] <= (3*i <= captured_num_catches) ? catch_times[3*i/4] : 32'd0;
                for (int j=0; j<captured_num_catches; j++) captured_catch_times[j] <= catch_times[j];
                if (captured_num_catches>0 || captured_num_families>0) state <= EVALUATE_WINDOWS;
                else state <= WAIT_DELAY;
            end
            EVALUATE_WINDOWS: begin
                for (int i=0; i<4; i++) begin
                    window_catches[i] <= 0;
                    for (int j=0; j<captured_num_catches; j++) begin
                        if (captured_catch_times[j] >= window_starts[i] && captured_catch_times[j] < window_starts[i]+WINDOW_DURATION) window_catches[i] <= window_catches[i]+1;
                    end
                end
                state <= COMPUTE_XP;
            end
            COMPUTE_XP: begin
                max_xp_internal <= 32'd0;
                for (int i=0; i<4; i++) begin
                    reg [31:0] catches = window_catches[i];
                    reg [31:0] xp_catch = catches * XP_CATCH;
                    reg [31:0] candies = catches * 3;
                    reg [31:0] evolutions = (captured_ev_cost == 0) ? 32'd0 : candies / captured_ev_cost;
                    reg [31:0] xp_evo = evolutions * XP_EVOLUTION;
                    max_xp_internal <= max_xp_internal > xp_catch + xp_evo ? max_xp_internal : xp_catch + xp_evo;
                end
                state <= WAIT_DELAY;
            end
            WAIT_DELAY: if (32'd100 > 1) begin state <= WAIT_DELAY; end else begin max_xp <= max_xp_internal; done <= 1'b1; state <= DONE; end
            DONE: ; endcase
        end
endmodule