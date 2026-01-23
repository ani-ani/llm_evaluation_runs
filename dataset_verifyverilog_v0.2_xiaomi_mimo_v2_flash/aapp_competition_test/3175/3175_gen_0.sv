module max_polygon_area(
    input clk,
    input rst_n,
    input start,
    input [3:0] segment_length,
    input [2:0] num_segments,
    input load_segment,
    output reg [31:0] max_area,
    output reg done
);

    localparam IDLE = 3'b000;
    localparam LOAD_SEGMENTS = 3'b001;
    localparam COUNT_FREQ = 3'b010;
    localparam COMPUTE_AREA = 3'b011;
    localparam DONE = 3'b100;

    reg [2:0] current_state;
    reg [2:0] next_state;
    
    reg [3:0] freq_count [10:1];
    reg [2:0] load_counter;
    
    // Compute registers
    reg [3:0] k;
    reg [3:0] s;
    reg [2:0] compute_step;
    reg [31:0] current_area;
    
    // Divider registers
    reg [31:0] div_n;
    reg [31:0] div_d;
    reg [31:0] div_rem;
    reg [4:0] div_bit;
    reg div_start;
    wire div_done = (div_bit == 5'd32);
    wire [31:0] div_quotient = div_n; // Result of restoring divider is in div_n if managed correctly
    
    // Control signals
    reg start_delayed;
    wire start_pulse = start & ~start_delayed;

    // --- State Register ---
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) current_state <= IDLE;
        else current_state <= next_state;
    end

    // --- Next State Logic ---
    always @(*) begin
        case (current_state)
            IDLE: next_state = start_pulse ? LOAD_SEGMENTS : IDLE;
            LOAD_SEGMENTS: next_state = (load_counter == num_segments) ? COUNT_FREQ : LOAD_SEGMENTS;
            COUNT_FREQ: next_state = COMPUTE_AREA;
            COMPUTE_AREA: begin
                if (compute_step == 3'd4 && (k >= num_segments || k >= 8)) next_state = DONE;
                else next_state = COMPUTE_AREA;
            end
            DONE: next_state = DONE;
            default: next_state = IDLE;
        endcase
    end

    // --- Datapath ---
    integer i;
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            max_area <= 0;
            done <= 0;
            load_counter <= 0;
            compute_step <= 0;
            k <= 3;
            s <= 1;
            start_delayed <= 0;
            div_start <= 0;
            div_bit <= 0;
            for (i = 1; i <= 10; i = i + 1) freq_count[i] <= 0;
        end else begin
            start_delayed <= start;
            
            case (current_state)
                IDLE: begin
                    done <= 0;
                    load_counter <= 0;
                    if (start_pulse) begin
                        for (i = 1; i <= 10; i = i + 1) freq_count[i] <= 0;
                    end
                end

                LOAD_SEGMENTS: begin
                    if (load_segment) begin
                        if (segment_length >= 1 && segment_length <= 10) begin
                            freq_count[segment_length] <= freq_count[segment_length] + 1;
                        end
                        if (load_counter < num_segments)
                            load_counter <= load_counter + 1;
                    end
                end

                COUNT_FREQ: begin
                    k <= 3;
                    s <= 1;
                    max_area <= 0;
                    compute_step <= 0;
                    div_start <= 0;
                end

                COMPUTE_AREA: begin
                    case (compute_step)
                        3'd0: begin // Check Frequency
                            if (freq_count[s] >= k && k <= num_segments && k <= 8) begin
                                compute_step <= 3'd1;
                            end else begin
                                // Move to next configuration
                                if (s < 10) begin
                                    s <= s + 1;
                                end else begin
                                    s <= 1;
                                    if (k < 8) k <= k + 1;
                                end
                            end
                        end

                        3'd1: begin // Setup Divider
                            // Calculate Numerator = (k * s * s * 65536)
                            // Calculate Denominator = 4 * tan(k)
                            // Using local constants for Denominator
                            div_n <= (k * s * s) << 16;
                            case(k)
                                3: div_d <= 32'd151352; // 37838 * 4
                                4: div_d <= 32'd262144; // 65536 * 4
                                5: div_d <= 32'd190504; // 47626 * 4
                                6: div_d <= 32'd151352; // 37838 * 4
                                7: div_d <= 32'd126256; // 31564 * 4
                                8: div_d <= 32'd108576; // 27144 * 4
                                default: div_d <= 1;
                            endcase
                            div_bit <= 0;
                            div_rem <= 0;
                            div_start <= 1;
                            compute_step <= 3'd2;
                        end

                        3'd2: begin // Divider Loop
                            div_start <= 0;
                            if (div_bit < 5'd32) begin
                                {div_rem, div_n} <= {div_rem[30:0], div_n, 1'b0};
                                if (div_rem >= div_d) begin
                                    div_rem <= div_rem - div_d;
                                    div_n[0] <= 1'b1;
                                end
                                div_bit <= div_bit + 1;
                            end else begin
                                compute_step <= 3'd3;
                            end
                        end

                        3'd3: begin // Capture Result & Compare
                            // div_n now contains the quotient
                            if (div_n > max_area) begin
                                max_area <= div_n;
                            end
                            compute_step <= 3'd4;
                        end

                        3'd4: begin // Next Iteration
                            // Update s and k loops
                            if (s < 10) begin
                                s <= s + 1;
                                compute_step <= 3'd0;
                            end else begin
                                s <= 1;
                                if (k < 8 && k < num_segments) begin
                                    k <= k + 1;
                                    compute_step <= 3'd0;
                                end
                                // If k reaches limit, state transition handles DONE
                            end
                        end
                    endcase
                end

                DONE: begin
                    done <= 1;
                end
            endcase
        end
    end

endmodule