module min_k_records(
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

    // State declarations
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] FILTER = 3'd1;
    localparam [2:0] SORT = 3'd2;
    localparam [2:0] SELECT = 3'd3;
    localparam [2:0] OUTPUT = 3'd4;

    reg [2:0] state, next_state;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd64;

    // Internal registers for filtered data
    reg [63:0] filtered_names [0:7];
    reg [7:0] filtered_values [0:7];
    reg [7:0] filtered_valid;
    reg [3:0] filtered_count;

    // Internal registers for sorting
    reg [63:0] sorted_names [0:7];
    reg [7:0] sorted_values [0:7];

    // Filter stage
    integer i, j;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            next_state <= IDLE;
            cycle_count <= 8'd0;
            done <= 1'b0;
            valid_count <= 4'd0;

            // Initialize all outputs
            for (i = 0; i < 8; i = i + 1) begin
                names_out[i] <= 64'd0;
                values_out[i] <= 8'd0;
                filtered_names[i] <= 64'd0;
                filtered_values[i] <= 8'd0;
                sorted_names[i] <= 64'd0;
                sorted_values[i] <= 8'd0;
            end
            filtered_valid <= 8'd0;
            filtered_count <= 4'd0;
        end else begin
            state <= next_state;
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                    if (start) begin
                        next_state <= FILTER;
                    end else begin
                        next_state <= IDLE;
                    end
                end

                FILTER: begin
                    // Filter valid records
                    filtered_count <= 4'd0;
                    for (i = 0; i < 8; i = i + 1) begin
                        if (valid_in[i]) begin
                            filtered_names[filtered_count] <= names_in[i];
                            filtered_values[filtered_count] <= values_in[i];
                            filtered_count <= filtered_count + 4'd1;
                        end
                    end
                    next_state <= SORT;
                end

                SORT: begin
                    // Bubble sort implementation
                    for (i = 0; i < 7; i = i + 1) begin
                        for (j = 0; j < 7 - i; j = j + 1) begin
                            if (filtered_values[j] > filtered_values[j + 1]) begin
                                // Swap values
                                sorted_values[j] <= filtered_values[j + 1];
                                sorted_values[j + 1] <= filtered_values[j];
                                // Swap names
                                sorted_names[j] <= filtered_names[j + 1];
                                sorted_names[j + 1] <= filtered_names[j];
                            end else begin
                                sorted_values[j] <= filtered_values[j];
                                sorted_values[j + 1] <= filtered_values[j + 1];
                                sorted_names[j] <= filtered_names[j];
                                sorted_names[j + 1] <= filtered_names[j + 1];
                            end
                        end
                    end
                    next_state <= SELECT;
                end

                SELECT: begin
                    // Select first K records
                    valid_count <= (K < filtered_count) ? K : filtered_count;
                    for (i = 0; i < 8; i = i + 1) begin
                        if (i < valid_count) begin
                            names_out[i] <= sorted_names[i];
                            values_out[i] <= sorted_values[i];
                        end else begin
                            names_out[i] <= 64'd0;
                            values_out[i] <= 8'd0;
                        end
                    end
                    next_state <= OUTPUT;
                end

                OUTPUT: begin
                    done <= 1'b1;
                    next_state <= IDLE;
                end

                default: begin
                    next_state <= IDLE;
                    done <= 1'b0;
                end
            endcase

            // Cycle counter for safety
            if (state != IDLE) begin
                cycle_count <= cycle_count + 8'd1;
                if (cycle_count >= MAX_CYCLES) begin
                    next_state <= IDLE;
                    done <= 1'b1;
                end
            end
        end
    end
endmodule