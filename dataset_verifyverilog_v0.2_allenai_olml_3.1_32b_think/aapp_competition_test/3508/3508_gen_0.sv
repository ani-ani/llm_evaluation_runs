module pillar_cascade (input clk, input rst_n, input start, input [2:0] n, input [7:0] b [0:7], output reg [2:0] max_damage, output reg [2:0] best_pillar, output reg done);
// Registers
reg [2:0] max_damage_reg;
reg [2:0] best_pillar_reg;
reg done_reg;
reg [2:0] current_i;
reg [2:0] n_val;
reg [7:0] b_vals [0:7];
reg [7:0] destroyed [0:7];
reg [3:0] total_destroyed;
reg [2:0] current_damage;

// State register
reg [2:0] state;
localparam IDLE = 3'b000;
localparam SETUP = 3'b001;
localparam SIMULATE = 3'b010;
localparam UPDATE_MAX = 3'b011;
localparam DONE_STATE = 3'b100;

// Default values
initial begin
    state <= IDLE;
    max_damage_reg <= 3'b000;
    best_pillar_reg <= 3'b000;
    done_reg <= 1'b0;
    current_i <= 3'b000;
    n_val <= 3'b000;
    b_vals <= 'd0;
    destroyed <= 'd0;
    total_destroyed <= 'd0;
    current_damage <= 'd0;
end

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        state <= IDLE;
        max_damage_reg <= 3'b000;
        best_pillar_reg <= 3'b000;
        done_reg <= 1'b0;
        current_i <= 3'b000;
        n_val <= 3'b000;
        b_vals <= 'd0;
        destroyed <= 'd0;
        total_destroyed <= 'd0;
        current_damage <= 'd0;
    end else begin
        case (state)
            IDLE: begin
                if (start) state <= SETUP;
            end
            SETUP: begin
                n_val <= n;
                b_vals <= b;
                current_i <= 3'b000;
                state <= SIMULATE;
            end
            SIMULATE: begin
                // Initialize for current_i
                destroyed <= 'd0;
                destroyed[current_i] <= 1'b1;
                total_destroyed <= 'd1;
                current_damage <= 'd1; // Assume only i is destroyed
                state <= UPDATE_MAX;
            end
            UPDATE_MAX: begin
                if (current_damage > max_damage_reg) begin
                    max_damage_reg <= current_damage;
                    best_pillar_reg <= current_i;
                end
                current_i <= current_i + 'd1;
                if (current_i < n_val) begin
                    state <= SIMULATE;
                end else begin
                    state <= DONE_STATE;
                end
            end
            DONE_STATE: begin
                done_reg <= 1'b1;
            end
        endcase
        max_damage <= max_damage_reg;
        best_pillar <= best_pillar_reg;
        done <= done_reg;
    end
endmodule