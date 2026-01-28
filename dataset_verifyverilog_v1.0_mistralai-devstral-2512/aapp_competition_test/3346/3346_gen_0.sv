module TrafficManager(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [7:0] cfg_t,
    input wire [4:0] cfg_n,
    input wire [19:0] cfg_car_dir,
    input wire [139:0] cfg_car_arr,
    input wire [119:0] cfg_car_irr,
    output reg [5:0] result,
    output reg done
);

    // State definitions
    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] COMPUTE = 2'd1;
    localparam [1:0] FINISHED = 2'd2;

    // State registers
    reg [1:0] state;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd999;

    // DP table memory (21x21x128x128)
    reg [6:0] dp_table [0:20] [0:20] [0:127] [0:127];

    // Car processing registers
    reg [4:0] car_idx;
    reg [4:0] west_count;
    reg [4:0] east_count;
    reg [6:0] west_time;
    reg [6:0] east_time;
    reg [6:0] current_time;
    reg [5:0] irritation_count;

    // Car data extraction
    wire [6:0] current_arrival;
    wire [5:0] current_irritation;
    wire current_dir;

    // Parallel comparator outputs
    wire [6:0] west_schedule_time;
    wire [6:0] east_schedule_time;

    // State machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 6'd0;
            done <= 1'b0;
            cycle_count <= 8'd0;
            car_idx <= 5'd0;
            west_count <= 5'd0;
            east_count <= 5'd0;
            west_time <= 7'd0;
            east_time <= 7'd0;
            irritation_count <= 6'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                    if (start) begin
                        state <= COMPUTE;
                        // Initialize DP table
                        dp_table[0][0][0][0] <= 7'd0;
                    end
                end

                COMPUTE: begin
                    cycle_count <= cycle_count + 8'd1;

                    // Extract current car data
                    current_arrival = cfg_car_arr[(car_idx * 7) +: 7];
                    current_irritation = cfg_car_irr[(car_idx * 6) +: 6];
                    current_dir = cfg_car_dir[car_idx];

                    // Process car based on direction
                    if (current_dir == 1'b0 && west_count < cfg_n) begin
                        // West car
                        west_schedule_time = (west_time + 3'd3) > current_arrival ? (west_time + 3'd3) : current_arrival;
                        west_time = west_schedule_time;
                        west_count = west_count + 5'd1;
                        
                        // Check irritation
                        if (west_schedule_time - current_arrival > current_irritation) begin
                            irritation_count = irritation_count + 6'd1;
                        end
                    end else if (current_dir == 1'b1 && east_count < cfg_n) begin
                        // East car
                        east_schedule_time = (east_time + 3'd3) > current_arrival ? (east_time + 3'd3) : current_arrival;
                        east_time = east_schedule_time;
                        east_count = east_count + 5'd1;
                        
                        // Check irritation
                        if (east_schedule_time - current_arrival > current_irritation) begin
                            irritation_count = irritation_count + 6'd1;
                        end
                    end

                    // Move to next car
                    car_idx = car_idx + 5'd1;

                    // Check if all cars processed
                    if (car_idx == cfg_n || cycle_count >= MAX_CYCLES) begin
                        state <= FINISHED;
                        result <= irritation_count;
                    end
                end

                FINISHED: begin
                    done <= 1'b1;
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end

    // Parallel comparator for West scheduling
    always @(*) begin
        if (west_time + 3'd3 > current_arrival) begin
            west_schedule_time = west_time + 3'd3;
        end else begin
            west_schedule_time = current_arrival;
        end
    end

    // Parallel comparator for East scheduling
    always @(*) begin
        if (east_time + 3'd3 > current_arrival) begin
            east_schedule_time = east_time + 3'd3;
        end else begin
            east_schedule_time = current_arrival;
        end
    end

endmodule