module anti_aging_pill_optimizer(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [15:0] n_scaled,
    input wire [15:0] c_scaled,
    input wire [3:0] pill_count,
    input wire [31:0] pill_t [0:7],
    input wire [7:0] pill_x [0:7],
    input wire [7:0] pill_y [0:7],
    output reg [31:0] result,
    output reg done,
    output reg valid
);

    // State declarations
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] INIT = 3'd1;
    localparam [2:0] COMPUTE = 3'd2;
    localparam [2:0] FINALIZE = 3'd3;
    localparam [2:0] DONE_STATE = 3'd4;

    reg [2:0] state;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd255;

    // DP table: 8 states (0-7 pills), 32-bit time (Q16.16)
    reg [31:0] dp_time [0:8];
    reg [31:0] dp_aging [0:8];
    reg [3:0] current_pill;
    reg [3:0] next_pill;
    reg [3:0] pill_iter;
    reg [3:0] state_iter;

    // Intermediate calculation registers
    reg [63:0] temp_mult;
    reg [31:0] temp_result;
    reg [31:0] max_time;

    // Convert inputs to internal format
    wire [31:0] n_internal = {{16'd0}, n_scaled};
    wire [31:0] c_internal = {{16'd0}, c_scaled};

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            cycle_count <= 8'd0;
            done <= 1'b0;
            valid <= 1'b0;
            result <= 32'd0;
            current_pill <= 4'd0;
            next_pill <= 4'd0;
            pill_iter <= 4'd0;
            state_iter <= 4'd0;
            max_time <= 32'd0;

            // Initialize DP table
            integer i;
            for (i = 0; i < 9; i = i + 1) begin
                dp_time[i] <= 32'd0;
                dp_aging[i] <= 32'd0;
            end
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    valid <= 1'b0;
                    cycle_count <= 8'd0;
                    if (start) begin
                        state <= INIT;
                    end
                end

                INIT: begin
                    // Initialize DP table
                    integer i;
                    for (i = 0; i < 9; i = i + 1) begin
                        dp_time[i] <= 32'd0;
                        dp_aging[i] <= 32'd0;
                    end
                    dp_time[0] <= 32'd0;
                    dp_aging[0] <= 32'd0;
                    current_pill <= 4'd0;
                    next_pill <= 4'd0;
                    pill_iter <= 4'd0;
                    state_iter <= 4'd0;
                    state <= COMPUTE;
                end

                COMPUTE: begin
                    cycle_count <= cycle_count + 8'd1;

                    // Iterate through pill combinations
                    if (pill_iter < pill_count + 4'd1 && state_iter < pill_count + 4'd1) begin
                        // Calculate aging factor for current pill
                        if (pill_x[pill_iter] != 8'd0) begin
                            temp_mult <= dp_aging[state_iter] * pill_t[pill_iter];
                            temp_result <= temp_mult[47:16] / pill_x[pill_iter];
                        end else begin
                            temp_result <= 32'd0;
                        end

                        // Add switch cost if changing pills
                        if (state_iter > 4'd0 && pill_iter != current_pill) begin
                            temp_result <= temp_result + c_internal;
                        end

                        // Update DP table
                        if (temp_result > dp_aging[pill_iter + 4'd1]) begin
                            dp_aging[pill_iter + 4'd1] <= temp_result;
                            dp_time[pill_iter + 4'd1] <= dp_time[state_iter] + pill_t[pill_iter];
                        end

                        // Move to next combination
                        if (pill_iter == pill_count) begin
                            pill_iter <= 4'd0;
                            state_iter <= state_iter + 4'd1;
                        end else begin
                            pill_iter <= pill_iter + 4'd1;
                        end
                    end else begin
                        state <= FINALIZE;
                    end

                    // Safety counter
                    if (cycle_count >= MAX_CYCLES) begin
                        state <= FINALIZE;
                    end
                end

                FINALIZE: begin
                    // Find maximum time that doesn't exceed n
                    integer i;
                    max_time <= 32'd0;
                    for (i = 0; i < 9; i = i + 1) begin
                        if (dp_time[i] <= n_internal && dp_aging[i] > max_time) begin
                            max_time <= dp_aging[i];
                        end
                    end
                    result <= max_time;
                    valid <= 1'b1;
                    state <= DONE_STATE;
                end

                DONE_STATE: begin
                    done <= 1'b1;
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end

endmodule