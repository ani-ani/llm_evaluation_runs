module chaos_calculator (
    input clk,
    input rst_n,
    input start,
    input [3:0] n,
    input [7:0] p0,
    input [7:0] p1,
    input [7:0] p2,
    input [7:0] p3,
    input [7:0] p4,
    input [7:0] p5,
    input [7:0] p6,
    input [7:0] p7,
    input [3:0] d0,
    input [3:0] d1,
    input [3:0] d2,
    input [3:0] d3,
    input [3:0] d4,
    input [3:0] d5,
    input [3:0] d6,
    input [3:0] d7,
    output reg [15:0] max_chaos,
    output reg done
);

    // State declarations
    localparam [2:0] IDLE      = 3'd0;
    localparam [2:0] RESET     = 3'd1;
    localparam [2:0] ACTIVATE  = 3'd2;
    localparam [2:0] COMPUTE   = 3'd3;
    localparam [2:0] UPDATE    = 3'd4;
    localparam [2:0] FINISH    = 3'd5;

    // Internal registers
    reg [2:0] state;
    reg [2:0] next_state;
    reg [3:0] step_counter;      // Current step (0 to n-1)
    reg [7:0] active_mask;       // Bit mask for active coaches
    reg [7:0] p_reg [0:7];       // Registered passenger counts
    reg [3:0] d_reg [0:7];       // Registered destruction orders
    reg [15:0] current_max;
    reg [3:0] activation_idx;    // Index of coach to activate
    reg [15:0] segment_chaos;    // Chaos for current segment
    reg [7:0] segment_mask;      // Mask for current segment
    reg [2:0] num_segments;      // Number of segments found
    reg [15:0] total_chaos;      // Sum of all segment chaos values
    reg [7:0] i_idx;             // Loop index for combinational logic
    reg [7:0] j_idx;             // Loop index for combinational logic
    reg [7:0] found_mask;        // Mask for finding segments
    reg [15:0] temp_chaos;       // Temporary chaos calculation

    // Combinational signals
    reg [15:0] next_max_chaos;
    reg [3:0] next_activation_idx;
    reg [15:0] calc_chaos;
    reg [7:0] next_active_mask;

    integer i, j;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            step_counter <= 4'd0;
            active_mask <= 8'd0;
            for (i = 0; i < 8; i = i + 1) begin
                p_reg[i] <= 8'd0;
                d_reg[i] <= 4'd0;
            end
            current_max <= 16'd0;
            max_chaos <= 16'd0;
            done <= 1'b0;
            activation_idx <= 4'd0;
            segment_chaos <= 16'd0;
            segment_mask <= 8'd0;
            num_segments <= 3'd0;
            total_chaos <= 16'd0;
            found_mask <= 8'd0;
            temp_chaos <= 16'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        // Register inputs
                        p_reg[0] <= p0;
                        p_reg[1] <= p1;
                        p_reg[2] <= p2;
                        p_reg[3] <= p3;
                        p_reg[4] <= p4;
                        p_reg[5] <= p5;
                        p_reg[6] <= p6;
                        p_reg[7] <= p7;
                        d_reg[0] <= d0;
                        d_reg[1] <= d1;
                        d_reg[2] <= d2;
                        d_reg[3] <= d3;
                        d_reg[4] <= d4;
                        d_reg[5] <= d5;
                        d_reg[6] <= d6;
                        d_reg[7] <= d7;
                        step_counter <= 4'd0;
                        active_mask <= 8'd0;
                        current_max <= 16'd0;
                        state <= ACTIVATE;
                    end
                end

                ACTIVATE: begin
                    // Find next coach to activate (reverse order)
                    for (j = 0; j < 8; j = j + 1) begin
                        if ((d_reg[j] == (n - step_counter)) && (active_mask[j] == 1'b0)) begin
                            next_activation_idx = j;
                        end
                    end
                    activation_idx <= next_activation_idx;
                    next_active_mask = active_mask;
                    next_active_mask[next_activation_idx] = 1'b1;
                    active_mask <= next_active_mask;
                    state <= COMPUTE;
                end

                COMPUTE: begin
                    // Reset computation variables
                    num_segments <= 3'd0;
                    total_chaos <= 16'd0;
                    found_mask <= 8'd0;
                    
                    // Check for segments among active coaches
                    for (i = 0; i < 8; i = i + 1) begin
                        if (active_mask[i] && !found_mask[i]) begin
                            // Start new segment
                            segment_mask <= 8'd0;
                            segment_mask[i] <= 1'b1;
                            found_mask[i] <= 1'b1;
                            
                            // Find connected coaches
                            for (j = 0; j < 8; j = j + 1) begin
                                if (j == i + 1 || j == i - 1) begin
                                    if (active_mask[j]) begin
                                        segment_mask[j] <= 1'b1;
                                        found_mask[j] <= 1'b1;
                                    end
                                end
                            end
                            
                            // Calculate segment chaos
                            // Sum passenger counts in segment
                            temp_chaos <= 16'd0;
                            for (j = 0; j < 8; j = j + 1) begin
                                if (segment_mask[j]) begin
                                    temp_chaos <= temp_chaos + {8'd0, p_reg[j]};
                                end
                            end
                            
                            // Apply formula: ((sum + 9) / 10) * 10
                            // This is equivalent to: (sum + 9) / 10 * 10
                            // Which simplifies to: ((sum + 9) / 10) * 10
                            // Since we're doing integer arithmetic, we can compute:
                            // chaos = ((temp_chaos + 9) / 10) * 10
                            // But division by 10 then multiply by 10 cancels out except for the rounding
                            // Actually, the formula is: ((sum + 9) / 10) * 10
                            // This rounds sum to nearest multiple of 10
                            calc_chaos <= ((temp_chaos + 9) / 10) * 10;
                            segment_chaos <= calc_chaos;
                            total_chaos <= total_chaos + calc_chaos;
                            num_segments <= num_segments + 1;
                        end
                    end
                    
                    state <= UPDATE;
                end

                UPDATE: begin
                    // Calculate total chaos * num_segments
                    if (num_segments > 3'd0) begin
                        temp_chaos <= total_chaos * {13'd0, num_segments};
                        if (temp_chaos > current_max) begin
                            current_max <= temp_chaos;
                        end
                    end
                    
                    step_counter <= step_counter + 4'd1;
                    
                    if (step_counter + 4'd1 >= n) begin
                        state <= FINISH;
                    end else begin
                        state <= ACTIVATE;
                    end
                end

                FINISH: begin
                    max_chaos <= current_max;
                    done <= 1'b1;
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end

endmodule