module FishGridCounter(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [63:0] grid_t,
    output reg [15:0] result,
    output reg done
);

    // Parameters
    localparam [5:0] GRID_SIZE = 6'd64;
    localparam [7:0] MAX_TIME = 8'd128;
    localparam [7:0] K = 8'd5;
    localparam [7:0] START_TIME = 8'd1;
    localparam [5:0] START_POS = 6'd0;

    // State declarations
    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] COMPUTE = 2'd1;
    localparam [1:0] FINISH = 2'd2;

    reg [1:0] state;
    reg [7:0] time_counter;
    reg [5:0] cell_index;
    reg [63:0] reachable_current;
    reg [63:0] reachable_next;
    reg [15:0] count;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd2000;

    // Initialize all registers
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            time_counter <= 8'd0;
            cell_index <= 6'd0;
            reachable_current <= 64'd0;
            reachable_next <= 64'd0;
            count <= 16'd0;
            result <= 16'd0;
            done <= 1'b0;
            cycle_count <= 8'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                    if (start) begin
                        state <= COMPUTE;
                        time_counter <= 8'd0;
                        cell_index <= 6'd0;
                        reachable_current <= 64'd0;
                        reachable_next <= 64'd0;
                        count <= 16'd0;
                        reachable_current[START_POS] <= 1'b1;
                    end
                end

                COMPUTE: begin
                    cycle_count <= cycle_count + 8'd1;
                    
                    // Check if we've processed all time steps
                    if (time_counter == MAX_TIME - 1'b1) begin
                        state <= FINISH;
                        result <= count;
                    end else begin
                        // Process current time step
                        if (cell_index == GRID_SIZE - 1'b1) begin
                            // Move to next time step
                            time_counter <= time_counter + 8'd1;
                            cell_index <= 6'd0;
                            reachable_current <= reachable_next;
                            reachable_next <= 64'd0;
                        end else begin
                            // Process current cell
                            reg [5:0] row = cell_index[5:3];
                            reg [5:0] col = cell_index[2:0];
                            reg [5:0] north = (row == 8'd0) ? 6'd0 : (row - 8'd1) * 8 + col;
                            reg [5:0] south = (row == 8'd7) ? 6'd0 : (row + 8'd1) * 8 + col;
                            reg [5:0] east = (col == 8'd7) ? 6'd0 : row * 8 + (col + 8'd1);
                            reg [5:0] west = (col == 8'd0) ? 6'd0 : row * 8 + (col - 8'd1);

                            // Update reachable_next from neighbors
                            if (time_counter > 8'd0) begin
                                if (reachable_current[north]) reachable_next[cell_index] <= 1'b1;
                                if (reachable_current[south]) reachable_next[cell_index] <= 1'b1;
                                if (reachable_current[east]) reachable_next[cell_index] <= 1'b1;
                                if (reachable_current[west]) reachable_next[cell_index] <= 1'b1;
                            end

                            // Check if current cell is eligible
                            reg [7:0] appear_time = grid_t[(cell_index * 8) +: 8];
                            if (reachable_current[cell_index] && 
                                time_counter >= appear_time && 
                                time_counter < appear_time + K) begin
                                count <= count + 16'd1;
                            end

                            cell_index <= cell_index + 6'd1;
                        end
                    end
                end

                FINISH: begin
                    done <= 1'b1;
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end

endmodule