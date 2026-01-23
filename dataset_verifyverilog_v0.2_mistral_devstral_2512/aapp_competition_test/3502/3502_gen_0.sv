module traffic_probability (
    input clk,
    input rst_n,
    input start,
    input [5:0] light_index,
    input [7:0] x_pos,
    input [7:0] r_dur,
    input [7:0] g_dur,
    input config_valid,
    output reg [31:0] prob_stop [3:0],
    output reg [31:0] prob_pass,
    output reg done
);

    // Parameters
    localparam IDLE = 3'b000;
    localparam CONFIG = 3'b001;
    localparam COMPUTE = 3'b010;
    localparam DONE = 3'b100;

    localparam NUM_LIGHTS = 4;
    localparam TIME_STEP = 8'd1; // 0.25s in Q8.8 (1/4)
    localparam MAX_CYCLE = 16; // Max cycle duration (r+g)

    // Internal registers
    reg [2:0] state;
    reg [7:0] light_config [3:0]; // x_pos, r_dur, g_dur for each light
    reg [7:0] cycle [3:0]; // r_dur + g_dur for each light
    reg [31:0] lcm_cycle; // LCM of all cycles
    reg [31:0] total_steps; // Total time steps in LCM period
    reg [31:0] current_step; // Current time step in sweep
    reg [31:0] stop_count [3:0]; // Stop counts for each light
    reg [31:0] pass_count; // Count of passing all lights
    reg [31:0] time_accum; // Accumulated time for current step
    reg [7:0] config_count; // Number of lights configured

    // State machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            config_count <= 0;
            done <= 0;
            for (int i = 0; i < NUM_LIGHTS; i++) begin
                light_config[i] <= 0;
                cycle[i] <= 0;
                prob_stop[i] <= 0;
            end
            prob_pass <= 0;
        end else begin
            case (state)
                IDLE: begin
                    if (start) begin
                        state <= CONFIG;
                        config_count <= 0;
                    end
                end
                CONFIG: begin
                    if (config_valid) begin
                        light_config[light_index] <= {x_pos, r_dur, g_dur};
                        cycle[light_index] <= r_dur + g_dur;
                        config_count <= config_count + 1;
                        if (config_count == NUM_LIGHTS - 1) begin
                            state <= COMPUTE;
                            // Calculate LCM of cycles
                            lcm_cycle <= compute_lcm(cycle[0], cycle[1], cycle[2], cycle[3]);
                            total_steps <= lcm_cycle * 4; // 0.25s steps
                            current_step <= 0;
                            for (int i = 0; i < NUM_LIGHTS; i++) begin
                                stop_count[i] <= 0;
                            end
                            pass_count <= 0;
                            time_accum <= 0;
                        end
                    end
                end
                COMPUTE: begin
                    if (current_step < total_steps) begin
                        // Simulate car travel for current time step
                        reg [7:0] arrival_time [3:0];
                        reg [7:0] light_state [3:0];
                        reg stopped;
                        stopped = 0;
                        
                        // Calculate arrival times and check light states
                        for (int i = 0; i < NUM_LIGHTS; i++) begin
                            arrival_time[i] <= time_accum[7:0] + light_config[i][15:8]; // x_pos
                            light_state[i] <= arrival_time[i] % cycle[i];
                            if (!stopped && light_state[i] < light_config[i][7:0]) begin // r_dur
                                stop_count[i] <= stop_count[i] + 1;
                                stopped = 1;
                            end
                        end
                        
                        if (!stopped) begin
                            pass_count <= pass_count + 1;
                        end
                        
                        // Increment step
                        current_step <= current_step + 1;
                        time_accum <= time_accum + TIME_STEP;
                    end else begin
                        state <= DONE;
                        done <= 1;
                        // Calculate probabilities (Q16.16)
                        for (int i = 0; i < NUM_LIGHTS; i++) begin
                            prob_stop[i] <= (stop_count[i] << 16) / total_steps;
                        end
                        prob_pass <= (pass_count << 16) / total_steps;
                    end
                end
                DONE: begin
                    if (!start) begin
                        state <= IDLE;
                        done <= 0;
                    end
                end
            endcase
        end
    end

    // LCM calculation function
    function [31:0] compute_lcm;
        input [7:0] a, b, c, d;
        reg [31:0] lcm_ab, lcm_cd, lcm_final;
        
        // LCM(a,b) = (a*b)/GCD(a,b)
        lcm_ab = (a * b) / gcd(a, b);
        lcm_cd = (c * d) / gcd(c, d);
        lcm_final = (lcm_ab * lcm_cd) / gcd(lcm_ab, lcm_cd);
        
        compute_lcm = lcm_final;
    endfunction

    // GCD calculation function
    function [7:0] gcd;
        input [7:0] a, b;
        reg [7:0] x, y, temp;
        
        x = a;
        y = b;
        while (y != 0) begin
            temp = y;
            y = x % y;
            x = temp;
        end
        
        gcd = x;
    endfunction

endmodule