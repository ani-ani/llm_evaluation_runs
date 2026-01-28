module FunctionDecomposition(
    input clk,
    input rst_n,
    input start,
    input [5:0] n,
    input [5:0] f_in,
    input f_valid,
    output reg result_valid,
    output reg possible,
    output reg [5:0] m,
    output reg [5:0] g_array,
    output reg [5:0] h_array,
    output reg [5:0] g_out_idx,
    output reg [5:0] h_out_idx,
    output reg g_read_en,
    output reg h_read_en
);

    // State declarations
    localparam [2:0] IDLE      = 3'd0;
    localparam [2:0] READ_F    = 3'd1;
    localparam [2:0] VERIFY    = 3'd2;
    localparam [2:0] CONSTRUCT = 3'd3;
    localparam [2:0] OUTPUT_G  = 3'd4;
    localparam [2:0] OUTPUT_H  = 3'd5;
    localparam [2:0] DONE      = 3'd6;

    reg [2:0] state, next_state;

    // Counters and indices
    reg [5:0] f_counter;
    reg [5:0] verify_counter;
    reg [5:0] construct_counter;
    reg [5:0] output_counter;
    reg [5:0] image_counter;

    // Arrays for f, g, h
    reg [5:0] f [0:63];
    reg [5:0] g [0:63];
    reg [5:0] h [0:63];

    // Image tracking
    reg [5:0] image [0:63];
    reg [5:0] image_size;

    // Temporary registers
    reg [5:0] temp_value;
    reg [5:0] temp_index;
    reg [5:0] temp_h_index;

    // Flags
    reg solution_exists;
    reg image_found;

    // Initialize all registers in reset
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            next_state <= IDLE;
            f_counter <= 6'd0;
            verify_counter <= 6'd0;
            construct_counter <= 6'd0;
            output_counter <= 6'd0;
            image_counter <= 6'd0;
            image_size <= 6'd0;
            solution_exists <= 1'b1;
            image_found <= 1'b0;
            result_valid <= 1'b0;
            possible <= 1'b0;
            m <= 6'd0;
            g_array <= 6'd0;
            h_array <= 6'd0;
            g_out_idx <= 6'd0;
            h_out_idx <= 6'd0;
            g_read_en <= 1'b0;
            h_read_en <= 1'b0;

            // Initialize arrays
            integer i;
            for (i = 0; i < 64; i = i + 1) begin
                f[i] <= 6'd0;
                g[i] <= 6'd0;
                h[i] <= 6'd0;
                image[i] <= 6'd0;
            end
        end else begin
            state <= next_state;
        end
    end

    // State machine logic
    always @(posedge clk) begin
        case (state)
            IDLE: begin
                if (start) begin
                    next_state <= READ_F;
                    f_counter <= 6'd0;
                    solution_exists <= 1'b1;
                    image_size <= 6'd0;
                    possible <= 1'b0;
                    result_valid <= 1'b0;
                    g_read_en <= 1'b0;
                    h_read_en <= 1'b0;
                end else begin
                    next_state <= IDLE;
                end
            end

            READ_F: begin
                if (f_valid && f_counter < n) begin
                    f[f_counter] <= f_in;
                    f_counter <= f_counter + 6'd1;
                    if (f_counter == n) begin
                        next_state <= VERIFY;
                        verify_counter <= 6'd0;
                    end
                end else begin
                    next_state <= READ_F;
                end
            end

            VERIFY: begin
                // Check if f(y) == y for all y in image
                temp_value <= f[verify_counter];
                if (temp_value != 6'd0 && temp_value <= n) begin
                    if (f[temp_value - 6'd1] != temp_value) begin
                        solution_exists <= 1'b0;
                    end
                end
                verify_counter <= verify_counter + 6'd1;
                if (verify_counter == n) begin
                    next_state <= CONSTRUCT;
                    construct_counter <= 6'd0;
                    image_counter <= 6'd0;
                    image_size <= 6'd0;
                end else begin
                    next_state <= VERIFY;
                end
            end

            CONSTRUCT: begin
                // Build image array (distinct values)
                temp_value <= f[construct_counter];
                image_found <= 1'b0;
                temp_index <= 6'd0;

                // Check if value is already in image
                for (temp_index = 6'd0; temp_index < image_size; temp_index = temp_index + 6'd1) begin
                    if (image[temp_index] == temp_value) begin
                        image_found <= 1'b1;
                    end
                end

                // If not found and value is valid, add to image
                if (!image_found && temp_value != 6'd0 && temp_value <= n) begin
                    image[image_size] <= temp_value;
                    image_size <= image_size + 6'd1;
                end

                construct_counter <= construct_counter + 6'd1;
                if (construct_counter == n) begin
                    // Sort image array (simple bubble sort)
                    integer i, j;
                    reg [5:0] temp_swap;
                    for (i = 0; i < image_size - 1; i = i + 1) begin
                        for (j = 0; j < image_size - i - 1; j = j + 1) begin
                            if (image[j] > image[j + 1]) begin
                                temp_swap = image[j];
                                image[j] = image[j + 1];
                                image[j + 1] = temp_swap;
                            end
                        end
                    end

                    // Build h array (sorted image)
                    for (i = 0; i < image_size; i = i + 1) begin
                        h[i] <= image[i];
                    end

                    // Build g array
                    for (i = 0; i < n; i = i + 1) begin
                        temp_value <= f[i];
                        temp_h_index <= 6'd0;
                        for (j = 0; j < image_size; j = j + 1) begin
                            if (h[j] == temp_value) begin
                                temp_h_index <= j + 6'd1;
                            end
                        end
                        g[i] <= temp_h_index;
                    end

                    m <= image_size;
                    possible <= solution_exists;
                    next_state <= OUTPUT_G;
                    output_counter <= 6'd0;
                    g_out_idx <= 6'd0;
                    g_read_en <= 1'b1;
                    h_read_en <= 1'b0;
                end else begin
                    next_state <= CONSTRUCT;
                end
            end

            OUTPUT_G: begin
                if (output_counter < n) begin
                    g_array <= g[output_counter];
                    g_out_idx <= output_counter + 6'd1;
                    output_counter <= output_counter + 6'd1;
                    if (output_counter == n) begin
                        next_state <= OUTPUT_H;
                        output_counter <= 6'd0;
                        g_read_en <= 1'b0;
                        h_read_en <= 1'b1;
                    end
                end else begin
                    next_state <= OUTPUT_G;
                end
            end

            OUTPUT_H: begin
                if (output_counter < m) begin
                    h_array <= h[output_counter];
                    h_out_idx <= output_counter + 6'd1;
                    output_counter <= output_counter + 6'd1;
                    if (output_counter == m) begin
                        next_state <= DONE;
                        h_read_en <= 1'b0;
                    end
                end else begin
                    next_state <= OUTPUT_H;
                end
            end

            DONE: begin
                result_valid <= 1'b1;
                next_state <= IDLE;
            end

            default: begin
                next_state <= IDLE;
            end
        endcase
    end

endmodule