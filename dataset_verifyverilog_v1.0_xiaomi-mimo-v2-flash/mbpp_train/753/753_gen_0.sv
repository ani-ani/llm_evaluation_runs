module MinimumKRecords(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [3:0] K,
    input wire [63:0] names_in [0:7],
    input wire [7:0] values_in [0:7],
    input wire [7:0] valid_in,
    output reg [63:0] names_out [0:7],
    output reg [7:0] values_out [0:7],
    output reg done,
    output reg [3:0] valid_count
);

    // Parameters
    localparam NUM_RECORDS = 8;
    localparam NAME_WIDTH = 64;
    localparam VALUE_WIDTH = 8;
    localparam MAX_K = 8;
    localparam MAX_CYCLES = 8'd64;

    // State definitions
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] FILTER = 3'd1;
    localparam [2:0] SORT = 3'd2;
    localparam [3:0] TRIM = 3'd3;
    localparam [3:0] FINISH = 3'd4;

    // Internal registers and wires
    reg [2:0] state;
    reg [2:0] next_state;
    reg [7:0] cycle_count;

    // Intermediate storage for filtered records
    reg [63:0] filtered_names [0:7];
    reg [7:0] filtered_values [0:7];
    reg [7:0] filtered_valid;
    reg [3:0] filtered_count;

    // Sorting registers (bubble sort network)
    reg [63:0] sort_names [0:7];
    reg [7:0] sort_values [0:7];
    reg [7:0] sort_valid;
    reg [3:0] sort_pass;
    reg [3:0] sort_idx;
    reg swap_flag;

    // Temporary registers for swap operation
    reg [63:0] temp_name;
    reg [7:0] temp_value;

    integer i;

    // State transition and output logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            valid_count <= 4'd0;
            cycle_count <= 8'd0;
            filtered_count <= 4'd0;
            sort_pass <= 4'd0;
            sort_idx <= 4'd0;
            sort_valid <= 8'd0;
            swap_flag <= 1'b0;

            // Initialize arrays
            for (i = 0; i < NUM_RECORDS; i = i + 1) begin
                names_out[i] <= 64'd0;
                values_out[i] <= 8'd0;
                filtered_names[i] <= 64'd0;
                filtered_values[i] <= 8'd0;
                sort_names[i] <= 64'd0;
                sort_values[i] <= 8'd0;
            end
        end else begin
            state <= next_state;

            case (state)
                IDLE: begin
                    done <= 1'b0;
                    valid_count <= 4'd0;
                    cycle_count <= 8'd0;
                    filtered_count <= 4'd0;
                    sort_pass <= 4'd0;
                    sort_idx <= 4'd0;
                    sort_valid <= 8'd0;
                    swap_flag <= 1'b0;
                end

                FILTER: begin
                    // Filter valid records
                    filtered_count <= 4'd0;
                    filtered_valid <= 8'd0;
                    for (i = 0; i < NUM_RECORDS; i = i + 1) begin
                        if (valid_in[i]) begin
                            filtered_names[filtered_count] <= names_in[i];
                            filtered_values[filtered_count] <= values_in[i];
                            filtered_valid[filtered_count] <= 1'b1;
                            filtered_count <= filtered_count + 4'd1;
                        end
                    end
                end

                SORT: begin
                    cycle_count <= cycle_count + 8'd1;
                    
                    // Initialize sort array from filtered
                    if (sort_pass == 4'd0 && sort_idx == 4'd0) begin
                        for (i = 0; i < NUM_RECORDS; i = i + 1) begin
                            sort_names[i] <= filtered_names[i];
                            sort_values[i] <= filtered_values[i];
                        end
                        sort_valid <= filtered_valid;
                    end

                    // Bubble sort pass
                    if (sort_idx < filtered_count - 4'd1) begin
                        if (sort_values[sort_idx] > sort_values[sort_idx + 1]) begin
                            // Swap
                            temp_name <= sort_names[sort_idx];
                            temp_value <= sort_values[sort_idx];
                            sort_names[sort_idx] <= sort_names[sort_idx + 1];
                            sort_values[sort_idx] <= sort_values[sort_idx + 1];
                            sort_names[sort_idx + 1] <= temp_name;
                            sort_values[sort_idx + 1] <= temp_value;
                            swap_flag <= 1'b1;
                        end
                    end
                end

                TRIM: begin
                    // Trim to K records
                    for (i = 0; i < NUM_RECORDS; i = i + 1) begin
                        if (i < K && i < filtered_count) begin
                            names_out[i] <= sort_names[i];
                            values_out[i] <= sort_values[i];
                        end else begin
                            names_out[i] <= 64'd0;
                            values_out[i] <= 8'd0;
                        end
                    end
                    
                    // Set valid_count
                    if (K < filtered_count) begin
                        valid_count <= K;
                    end else begin
                        valid_count <= filtered_count;
                    end
                end

                FINISH: begin
                    done <= 1'b1;
                end
            endcase
        end
    end

    // Next state logic
    always @(*) begin
        next_state = state;
        
        case (state)
            IDLE: begin
                if (start) begin
                    next_state = FILTER;
                end
            end

            FILTER: begin
                next_state = SORT;
            end

            SORT: begin
                if (sort_idx < filtered_count - 4'd1) begin
                    if (sort_idx < filtered_count - 4'd2) begin
                        next_state = SORT;
                    end else begin
                        next_state = SORT;
                    end
                end else begin
                    if (sort_pass < filtered_count - 4'd1 && cycle_count < MAX_CYCLES) begin
                        next_state = SORT;
                    end else begin
                        next_state = TRIM;
                    end
                end
            end

            TRIM: begin
                next_state = FINISH;
            end

            FINISH: begin
                next_state = IDLE;
            end

            default: begin
                next_state = IDLE;
            end
        endcase
    end

    // Internal control logic for bubble sort
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            sort_idx <= 4'd0;
            sort_pass <= 4'd0;
        end else begin
            if (state == SORT) begin
                if (sort_idx < filtered_count - 4'd1) begin
                    sort_idx <= sort_idx + 4'd1;
                end else begin
                    sort_idx <= 4'd0;
                    sort_pass <= sort_pass + 4'd1;
                end
            end else if (state == IDLE) begin
                sort_idx <= 4'd0;
                sort_pass <= 4'd0;
            end
        end
    end

endmodule