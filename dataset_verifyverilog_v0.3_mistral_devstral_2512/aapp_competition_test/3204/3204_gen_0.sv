module bridge_controller(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [15:0] t0, t1, t2, t3, t4, t5, t6, t7,
    input wire [2:0] num_boats,
    output reg [31:0] total_time,
    output reg done
);

    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] READ = 3'd1;
    localparam [2:0] CHECK_GROUP = 3'd2;
    localparam [2:0] NEXT_BOAT = 3'd3;
    localparam [2:0] FINAL_COST = 3'd4;
    localparam [2:0] DONE_STATE = 3'd5;

    reg [2:0] state;
    reg [2:0] i;
    reg [31:0] accum_time;
    reg [15:0] group_start_time;
    reg [2:0] group_size;
    reg [15:0] current_boat_time;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            total_time <= 32'd0;
            done <= 1'b0;
            i <= 3'd0;
            accum_time <= 32'd0;
            group_start_time <= 16'd0;
            group_size <= 3'd0;
            current_boat_time <= 16'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        state <= READ;
                        i <= 3'd0;
                        accum_time <= 32'd0;
                        group_size <= 3'd0;
                    end
                end

                READ: begin
                    case (i)
                        3'd0: current_boat_time <= t0;
                        3'd1: current_boat_time <= t1;
                        3'd2: current_boat_time <= t2;
                        3'd3: current_boat_time <= t3;
                        3'd4: current_boat_time <= t4;
                        3'd5: current_boat_time <= t5;
                        3'd6: current_boat_time <= t6;
                        3'd7: current_boat_time <= t7;
                        default: current_boat_time <= 16'd0;
                    endcase
                    state <= CHECK_GROUP;
                end

                CHECK_GROUP: begin
                    if (group_size == 3'd0) begin
                        group_start_time <= current_boat_time;
                        group_size <= 3'd1;
                        state <= NEXT_BOAT;
                    end else if (current_boat_time - group_start_time > 16'd1800) begin
                        accum_time <= accum_time + 32'd120 + (32'd20 * group_size);
                        group_start_time <= current_boat_time;
                        group_size <= 3'd1;
                        state <= NEXT_BOAT;
                    end else begin
                        group_size <= group_size + 3'd1;
                        state <= NEXT_BOAT;
                    end
                end

                NEXT_BOAT: begin
                    i <= i + 3'd1;
                    if (i < num_boats) begin
                        state <= READ;
                    end else begin
                        state <= FINAL_COST;
                    end
                end

                FINAL_COST: begin
                    if (group_size > 3'd0) begin
                        total_time <= accum_time + 32'd120 + (32'd20 * group_size);
                    end else begin
                        total_time <= accum_time;
                    end
                    state <= DONE_STATE;
                    done <= 1'b1;
                end

                DONE_STATE: begin
                    if (!start) begin
                        state <= IDLE;
                        done <= 1'b0;
                    end
                end

                default: state <= IDLE;
            endcase
        end
    end
endmodule