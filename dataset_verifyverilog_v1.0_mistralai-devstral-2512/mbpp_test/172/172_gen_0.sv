module std_counter(
    input clk,
    input rst_n,
    input start,
    input char_valid,
    input [7:0] char_in,
    input [3:0] len,
    output reg [3:0] result,
    output reg done
);

    // State declarations
    localparam [2:0] IDLE      = 3'd0;
    localparam [2:0] LOAD      = 3'd1;
    localparam [2:0] COMPARE   = 3'd2;
    localparam [2:0] FINISH    = 3'd3;

    // Internal buffer and registers
    reg [7:0] buffer [0:15];
    reg [2:0] state, next_state;
    reg [3:0] index;
    reg [3:0] count;
    reg [7:0] char_s, char_t, char_d;
    reg match_s, match_t, match_d;
    reg [7:0] current_char;
    reg [3:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd128;

    // State machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 4'd0;
            done <= 1'b0;
            index <= 4'd0;
            count <= 4'd0;
            cycle_count <= 8'd0;
            match_s <= 1'b0;
            match_t <= 1'b0;
            match_d <= 1'b0;
            char_s <= 8'd0;
            char_t <= 8'd0;
            char_d <= 8'd0;
            // Initialize buffer
            integer i;
            for (i = 0; i < 16; i = i + 1) begin
                buffer[i] <= 8'd0;
            end
        end else begin
            state <= next_state;
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                    if (start) begin
                        next_state <= LOAD;
                    end else begin
                        next_state <= IDLE;
                    end
                end

                LOAD: begin
                    cycle_count <= cycle_count + 8'd1;
                    if (char_valid) begin
                        buffer[index] <= char_in;
                        index <= index + 4'd1;
                        if (index == len) begin
                            index <= 4'd0;
                            next_state <= COMPARE;
                        end else begin
                            next_state <= LOAD;
                        end
                    end else begin
                        next_state <= LOAD;
                    end
                end

                COMPARE: begin
                    cycle_count <= cycle_count + 8'd1;
                    current_char <= buffer[index];
                    char_s <= current_char;
                    match_s <= (char_s == 8'h73);
                    next_state <= COMPARE;

                    if (index < (len - 3)) begin
                        index <= index + 4'd1;
                    end else begin
                        index <= 4'd0;
                        next_state <= FINISH;
                    end
                end

                FINISH: begin
                    cycle_count <= cycle_count + 8'd1;
                    char_t <= buffer[index];
                    match_t <= (char_t == 8'h74);
                    next_state <= FINISH;

                    if (index < (len - 3)) begin
                        index <= index + 4'd1;
                    end else begin
                        index <= 4'd0;
                        next_state <= FINISH;
                    end
                end

                default: begin
                    next_state <= IDLE;
                    done <= 1'b0;
                end
            endcase
        end
    end

    // Pipeline stages for comparison
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            char_t <= 8'd0;
            char_d <= 8'd0;
            match_t <= 1'b0;
            match_d <= 1'b0;
        end else begin
            // Stage 2: Compare 't'
            if (state == COMPARE) begin
                char_t <= char_s;
                match_t <= match_s;
            end

            // Stage 3: Compare 'd'
            if (state == COMPARE) begin
                char_d <= char_t;
                match_d <= match_t;
            end
        end
    end

    // Count matches
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            count <= 4'd0;
        end else begin
            if (state == COMPARE && match_s && match_t && match_d) begin
                count <= count + 4'd1;
            end
        end
    end

    // Output result and done
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            result <= 4'd0;
            done <= 1'b0;
        end else begin
            if (state == FINISH && index == 4'd0) begin
                result <= count;
                done <= 1'b1;
            end else begin
                done <= 1'b0;
            end
        end
    end

    // Safety: Prevent infinite loops
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            cycle_count <= 8'd0;
        end else begin
            if (cycle_count >= MAX_CYCLES) begin
                state <= IDLE;
                done <= 1'b1;
                result <= count;
            end
        end
    end

endmodule