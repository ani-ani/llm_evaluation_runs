module TrafficManagement(
    input clk,
    input rst_n,
    input start,
    input [7:0] cfg_t,
    input [4:0] cfg_n,
    input [19:0] cfg_car_dir,
    input [139:0] cfg_car_arr,
    input [119:0] cfg_car_irr,
    output reg [5:0] result,
    output reg done
);

    // State declarations
    localparam [1:0] IDLE     = 2'd0;
    localparam [1:0] COMPUTE  = 2'd1;
    localparam [1:0] FINISHED = 2'd2;

    // Internal registers
    reg [1:0] state, next_state;
    reg [5:0] result_reg;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd100;

    // Configuration registers
    reg [7:0] t_reg;
    reg [4:0] n_reg;
    reg [19:0] dir_reg;
    reg [139:0] arr_reg;
    reg [119:0] irr_reg;

    // Counters for car processing
    reg [4:0] west_count_total;
    reg [4:0] east_count_total;
    reg [4:0] west_processed;
    reg [4:0] east_processed;
    reg [4:0] current_car_idx;

    // Time tracking
    reg [7:0] prev_west_time;
    reg [7:0] prev_east_time;
    reg [7:0] curr_arrival;
    reg [5:0] curr_irr;
    reg curr_dir;
    reg [7:0] scheduled_time;
    reg [7:0] delay;
    reg irritated;

    // Computation state
    reg [2:0] compute_state;
    localparam [2:0] COMP_INIT      = 3'd0;
    localparam [2:0] COMP_FETCH     = 3'd1;
    localparam [2:0] COMP_CALC      = 3'd2;
    localparam [2:0] COMP_UPDATE    = 3'd3;
    localparam [2:0] COMP_NEXT      = 3'd4;
    localparam [2:0] COMP_DONE      = 3'd5;

    // DP table for result storage
    reg [6:0] dp_result;

    // Done signal control
    reg done_set;

    // Combinational logic for current car extraction
    wire [6:0] curr_arr_wires [19:0];
    wire [5:0] curr_irr_wires [19:0];
    wire [19:0] curr_dir_wires;
    
    genvar i;
    generate
        for (i = 0; i < 20; i = i + 1) begin : gen_car
            assign curr_arr_wires[i] = arr_reg[i*7 +: 7];
            assign curr_irr_wires[i] = irr_reg[i*6 +: 6];
        end
        assign curr_dir_wires = dir_reg;
    endgenerate

    // State transition logic
    always @(*) begin
        case (state)
            IDLE: begin
                if (start) begin
                    next_state = COMPUTE;
                end else begin
                    next_state = IDLE;
                end
            end
            COMPUTE: begin
                if (compute_state == COMP_DONE) begin
                    next_state = FINISHED;
                end else begin
                    next_state = COMPUTE;
                end
            end
            FINISHED: begin
                next_state = IDLE;
            end
            default: next_state = IDLE;
        endcase
    end

    // Main sequential logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result_reg <= 6'd0;
            done <= 1'b0;
            done_set <= 1'b0;
            cycle_count <= 8'd0;
            t_reg <= 8'd0;
            n_reg <= 5'd0;
            dir_reg <= 20'd0;
            arr_reg <= 140'd0;
            irr_reg <= 120'd0;
            west_count_total <= 5'd0;
            east_count_total <= 5'd0;
            west_processed <= 5'd0;
            east_processed <= 5'd0;
            current_car_idx <= 5'd0;
            prev_west_time <= 8'd0;
            prev_east_time <= 8'd0;
            curr_arrival <= 8'd0;
            curr_irr <= 6'd0;
            curr_dir <= 1'b0;
            scheduled_time <= 8'd0;
            delay <= 8'd0;
            irritated <= 1'b0;
            compute_state <= COMP_INIT;
            dp_result <= 7'd0;
        end else begin
            state <= next_state;
            cycle_count <= cycle_count + 8'd1;

            case (state)
                IDLE: begin
                    done <= 1'b0;
                    done_set <= 1'b0;
                    cycle_count <= 8'd0;
                    if (start) begin
                        // Store configuration
                        t_reg <= cfg_t;
                        n_reg <= cfg_n;
                        dir_reg <= cfg_car_dir;
                        arr_reg <= cfg_car_arr;
                        irr_reg <= cfg_car_irr;

                        // Count cars
                        west_count_total <= 5'd0;
                        east_count_total <= 5'd0;
                        result_reg <= 6'd0;
                        dp_result <= 7'd0;

                        // Initialize counters
                        west_processed <= 5'd0;
                        east_processed <= 5'd0;
                        current_car_idx <= 5'd0;
                        prev_west_time <= 8'd0;
                        prev_east_time <= 8'd0;
                        compute_state <= COMP_INIT;
                    end
                end

                COMPUTE: begin
                    case (compute_state)
                        COMP_INIT: begin
                            // Count total west and east cars
                            if (current_car_idx < n_reg) begin
                                if (cfg_car_dir[current_car_idx]) begin
                                    east_count_total <= east_count_total + 5'd1;
                                end else begin
                                    west_count_total <= west_count_total + 5'd1;
                                end
                                current_car_idx <= current_car_idx + 5'd1;
                            end else begin
                                current_car_idx <= 5'd0;
                                compute_state <= COMP_FETCH;
                            end
                        end

                        COMP_FETCH: begin
                            // Extract current car data
                            if (current_car_idx < n_reg) begin
                                curr_arrival <= arr_reg[current_car_idx*7 +: 7];
                                curr_irr <= irr_reg[current_car_idx*6 +: 6];
                                curr_dir <= cfg_car_dir[current_car_idx];
                                compute_state <= COMP_CALC;
                            end else begin
                                compute_state <= COMP_DONE;
                            end
                        end

                        COMP_CALC: begin
                            // Determine scheduled time and check irritation
                            irritated <= 1'b0;
                            if (curr_dir == 1'b0) begin
                                // West car
                                if (west_processed < west_count_total) begin
                                    delay <= (prev_west_time > 8'd2) ? (prev_west_time + 8'd3) : 8'd3;
                                    if (delay > curr_arrival) begin
                                        scheduled_time <= delay;
                                    end else begin
                                        scheduled_time <= curr_arrival;
                                    end
                                    if ((scheduled_time - curr_arrival) > curr_irr) begin
                                        irritated <= 1'b1;
                                    end
                                end
                            end else begin
                                // East car
                                if (east_processed < east_count_total) begin
                                    delay <= (prev_east_time > 8'd2) ? (prev_east_time + 8'd3) : 8'd3;
                                    if (delay > curr_arrival) begin
                                        scheduled_time <= delay;
                                    end else begin
                                        scheduled_time <= curr_arrival;
                                    end
                                    if ((scheduled_time - curr_arrival) > curr_irr) begin
                                        irritated <= 1'b1;
                                    end
                                end
                            end
                            compute_state <= COMP_UPDATE;
                        end

                        COMP_UPDATE: begin
                            // Update processing counts and times
                            if (curr_dir == 1'b0) begin
                                if (west_processed < west_count_total) begin
                                    prev_west_time <= scheduled_time;
                                    west_processed <= west_processed + 5'd1;
                                end
                            end else begin
                                if (east_processed < east_count_total) begin
                                    prev_east_time <= scheduled_time;
                                    east_processed <= east_processed + 5'd1;
                                end
                            end

                            // Update irritation count
                            if (irritated) begin
                                result_reg <= result_reg + 6'd1;
                            end

                            compute_state <= COMP_NEXT;
                        end

                        COMP_NEXT: begin
                            current_car_idx <= current_car_idx + 5'd1;
                            compute_state <= COMP_FETCH;
                        end

                        COMP_DONE: begin
                            dp_result <= {1'b0, result_reg};
                        end

                        default: compute_state <= COMP_INIT;
                    endcase
                end

                FINISHED: begin
                    done <= 1'b1;
                    result <= result_reg;
                end

                default: begin
                    state <= IDLE;
                end
            endcase
        end
    end

endmodule