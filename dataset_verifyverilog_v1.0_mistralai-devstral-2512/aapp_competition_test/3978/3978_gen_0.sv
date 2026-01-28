module color_counter(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [3:0] n,
    input wire [6:0] a_i,
    input wire [3:0] addr_wr,
    input wire wr_en,
    output reg [4:0] result,
    output reg done
);

    // State declarations
    localparam [2:0] IDLE   = 3'd0;
    localparam [2:0] LOAD   = 3'd1;
    localparam [2:0] SORT   = 3'd2;
    localparam [2:0] COUNT  = 3'd3;
    localparam [2:0] DONE_STATE = 3'd4;

    // Internal registers
    reg [2:0] state, next_state;
    reg [6:0] arr [0:15];
    reg [3:0] load_count;
    reg [3:0] sort_i, sort_j;
    reg [3:0] count_i, count_j;
    reg [4:0] color_count;
    reg [3:0] used [0:15];
    reg [3:0] temp;
    reg [6:0] remainder;
    reg [6:0] dividend, divisor;
    reg [3:0] sub_count;
    reg [6:0] quotient;

    // State machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 5'd0;
            done <= 1'b0;
            load_count <= 4'd0;
            sort_i <= 4'd0;
            sort_j <= 4'd0;
            count_i <= 4'd0;
            count_j <= 4'd0;
            color_count <= 5'd0;
            temp <= 4'd0;
            remainder <= 7'd0;
            dividend <= 7'd0;
            divisor <= 7'd0;
            sub_count <= 4'd0;
            quotient <= 7'd0;
            for (temp = 0; temp < 16; temp = temp + 1) begin
                arr[temp] <= 7'd0;
                used[temp] <= 4'd0;
            end
        end else begin
            state <= next_state;
        end
    end

    // Next state logic
    always @(*) begin
        next_state = state;
        case (state)
            IDLE: begin
                if (start) begin
                    next_state = LOAD;
                end
            end
            
            LOAD: begin
                if (load_count == n - 1) begin
                    next_state = SORT;
                end
            end
            
            SORT: begin
                if (sort_i == n - 1 && sort_j == n - sort_i - 1) begin
                    next_state = COUNT;
                end
            end
            
            COUNT: begin
                if (count_i == n - 1 && count_j == n) begin
                    next_state = DONE_STATE;
                end
            end
            
            DONE_STATE: begin
                next_state = IDLE;
            end
            
            default: next_state = IDLE;
        endcase
    end

    // Load array
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            load_count <= 4'd0;
        end else if (state == LOAD && wr_en) begin
            arr[addr_wr] <= a_i;
            load_count <= load_count + 1'b1;
        end
    end

    // Bubble sort
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            sort_i <= 4'd0;
            sort_j <= 4'd0;
        end else if (state == SORT) begin
            if (arr[sort_j] > arr[sort_j + 1]) begin
                temp <= arr[sort_j];
                arr[sort_j] <= arr[sort_j + 1];
                arr[sort_j + 1] <= temp;
            end
            if (sort_j == n - sort_i - 2) begin
                sort_j <= 4'd0;
                sort_i <= sort_i + 1'b1;
            end else begin
                sort_j <= sort_j + 1'b1;
            end
        end
    end

    // Count colors
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            count_i <= 4'd0;
            count_j <= 4'd0;
            color_count <= 5'd0;
            for (temp = 0; temp < 16; temp = temp + 1) begin
                used[temp] <= 4'd0;
            end
        end else if (state == COUNT) begin
            if (used[count_i] == 0) begin
                color_count <= color_count + 1'b1;
                used[count_i] <= 1'b1;
                count_j <= count_i + 1'b1;
            end else if (count_j < n) begin
                // Modulo operation
                if (divisor == 0) begin
                    used[count_j] <= 0;
                    count_j <= count_j + 1'b1;
                end else begin
                    if (sub_count == 0) begin
                        dividend <= arr[count_j];
                        divisor <= arr[count_i];
                        quotient <= 7'd0;
                        remainder <= 7'd0;
                        sub_count <= 4'd1;
                    end else if (sub_count <= dividend[6:0] + 1) begin
                        if (remainder >= divisor) begin
                            remainder <= remainder - divisor;
                            quotient <= quotient + 1'b1;
                        end
                        sub_count <= sub_count + 1'b1;
                    end else begin
                        if (remainder == 0) begin
                            used[count_j] <= 1'b1;
                        end
                        count_j <= count_j + 1'b1;
                        sub_count <= 4'd0;
                    end
                end
            end else begin
                count_i <= count_i + 1'b1;
                count_j <= 4'd0;
            end
        end
    end

    // Done signal
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            done <= 1'b0;
        end else if (state == DONE_STATE) begin
            done <= 1'b1;
            result <= color_count;
        end else begin
            done <= 1'b0;
        end
    end

endmodule