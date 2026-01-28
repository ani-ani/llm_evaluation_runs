module student_filter (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [47:0] students [0:7],
    input wire [15:0] min_height,
    input wire [15:0] min_weight,
    output reg [7:0] filtered,
    output reg [3:0] result_count,
    output reg done
);

    // State machine definitions
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] LOAD = 3'd1;
    localparam [2:0] COMPARE = 3'd2;
    localparam [2:0] UPDATE = 3'd3;
    localparam [2:0] INCREMENT = 3'd4;
    localparam [2:0] FINISH = 3'd5;

    // Internal registers
    reg [2:0] state, next_state;
    reg [2:0] index;  // Student index 0-7
    reg [15:0] current_height;
    reg [15:0] current_weight;
    reg [3:0] count;
    reg [7:0] filtered_reg;
    reg [7:0] cycle_counter;
    localparam [7:0] MAX_CYCLES = 8'd100;

    // Output assignments
    assign filtered = filtered_reg;
    assign result_count = count;

    // State transition logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            index <= 3'd0;
            current_height <= 16'd0;
            current_weight <= 16'd0;
            count <= 4'd0;
            filtered_reg <= 8'd0;
            done <= 1'b0;
            cycle_counter <= 8'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    count <= 4'd0;
                    filtered_reg <= 8'd0;
                    index <= 3'd0;
                    cycle_counter <= 8'd0;
                    if (start) begin
                        state <= LOAD;
                    end else begin
                        state <= IDLE;
                    end
                end

                LOAD: begin
                    // Extract height and weight from student data
                    current_height <= {students[index][15:8], students[index][7:0]};
                    current_weight <= {students[index][23:16], students[index][31:24]};
                    state <= COMPARE;
                    cycle_counter <= cycle_counter + 8'd1;
                end

                COMPARE: begin
                    // Compare with thresholds using unsigned 16-bit comparison
                    if ((current_height >= min_height) && (current_weight >= min_weight)) begin
                        filtered_reg[index] <= 1'b1;
                        count <= count + 4'd1;
                    end else begin
                        filtered_reg[index] <= 1'b0;
                    end
                    state <= INCREMENT;
                    cycle_counter <= cycle_counter + 8'd1;
                end

                INCREMENT: begin
                    if (index < 3'd7) begin
                        index <= index + 3'd1;
                        state <= LOAD;
                    end else begin
                        state <= FINISH;
                    end
                    cycle_counter <= cycle_counter + 8'd1;
                end

                FINISH: begin
                    done <= 1'b1;
                    state <= IDLE;
                    cycle_counter <= cycle_counter + 8'd1;
                end

                default: begin
                    state <= IDLE;
                    index <= 3'd0;
                    count <= 4'd0;
                    filtered_reg <= 8'd0;
                    cycle_counter <= 8'd0;
                end
            endcase

            // Safety timeout to prevent infinite loops
            if (cycle_counter >= MAX_CYCLES && state != IDLE && state != FINISH) begin
                state <= FINISH;
            end
        end
    end

endmodule