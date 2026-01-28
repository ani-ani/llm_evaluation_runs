module TVShowScheduler(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [3:0] n,
    input wire [3:0] k,
    input wire signed [31:0] x [0:15],
    input wire signed [31:0] y [0:15],
    output reg [15:0] result,
    output reg done
);

    // State declarations
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] SORT = 3'd1;
    localparam [2:0] SCHEDULE = 3'd2;
    localparam [2:0] FINISH = 3'd3;
    
    reg [2:0] state;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd500;

    // Sorting variables
    reg [3:0] sort_i;
    reg [3:0] sort_j;
    reg [3:0] sort_n;
    reg signed [31:0] sorted_x [0:15];
    reg signed [31:0] sorted_y [0:15];
    reg signed [31:0] temp_x;
    reg signed [31:0] temp_y;

    // Scheduling variables
    reg [3:0] schedule_i;
    reg [3:0] schedule_k;
    reg [3:0] count;
    reg signed [31:0] slot_end [0:3];
    reg [3:0] current_n;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 16'd0;
            done <= 1'b0;
            cycle_count <= 8'd0;
            sort_i <= 4'd0;
            sort_j <= 4'd0;
            sort_n <= 4'd0;
            schedule_i <= 4'd0;
            schedule_k <= 4'd0;
            count <= 4'd0;
            current_n <= 4'd0;
            
            // Initialize sorted arrays
            integer i;
            for (i = 0; i < 16; i = i + 1) begin
                sorted_x[i] <= 32'd0;
                sorted_y[i] <= 32'd0;
            end
            
            // Initialize slot ends
            for (i = 0; i < 4; i = i + 1) begin
                slot_end[i] <= 32'd0;
            end
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                    if (start) begin
                        state <= SORT;
                        sort_n <= n;
                        current_n <= n;
                        
                        // Copy input to sorted arrays
                        integer i;
                        for (i = 0; i < 16; i = i + 1) begin
                            if (i < n) begin
                                sorted_x[i] <= x[i];
                                sorted_y[i] <= y[i];
                            end else begin
                                sorted_x[i] <= 32'd0;
                                sorted_y[i] <= 32'd0;
                            end
                        end
                    end
                end
                
                SORT: begin
                    cycle_count <= cycle_count + 8'd1;
                    
                    // Bubble sort by end time
                    if (sort_i < sort_n - 1) begin
                        if (sort_j < sort_n - sort_i - 1) begin
                            if (sorted_y[sort_j] > sorted_y[sort_j + 1]) begin
                                // Swap
                                temp_x <= sorted_x[sort_j];
                                temp_y <= sorted_y[sort_j];
                                sorted_x[sort_j] <= sorted_x[sort_j + 1];
                                sorted_y[sort_j] <= sorted_y[sort_j + 1];
                                sorted_x[sort_j + 1] <= temp_x;
                                sorted_y[sort_j + 1] <= temp_y;
                            end
                            sort_j <= sort_j + 4'd1;
                        end else begin
                            sort_j <= 4'd0;
                            sort_i <= sort_i + 4'd1;
                        end
                    end else begin
                        sort_i <= 4'd0;
                        sort_j <= 4'd0;
                        state <= SCHEDULE;
                    end
                end
                
                SCHEDULE: begin
                    cycle_count <= cycle_count + 8'd1;
                    
                    if (schedule_i < current_n) begin
                        if (schedule_k < k) begin
                            // Check if this slot can take the show
                            if (slot_end[schedule_k] <= sorted_x[schedule_i]) begin
                                // Assign show to this slot
                                slot_end[schedule_k] <= sorted_y[schedule_i];
                                count <= count + 4'd1;
                                schedule_k <= 4'd0;
                                schedule_i <= schedule_i + 4'd1;
                            end else begin
                                schedule_k <= schedule_k + 4'd1;
                            end
                        end else begin
                            // No available slot, move to next show
                            schedule_k <= 4'd0;
                            schedule_i <= schedule_i + 4'd1;
                        end
                    end else begin
                        // All shows processed
                        result <= count;
                        state <= FINISH;
                    end
                end
                
                FINISH: begin
                    done <= 1'b1;
                    state <= IDLE;
                end
                
                default: begin
                    state <= IDLE;
                    done <= 1'b0;
                    result <= 16'd0;
                end
            endcase
        end
    end
endmodule