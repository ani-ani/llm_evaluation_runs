module wiring_counter (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [3:0] n,
    input wire [3:0] m,
    input wire [31:0] switch_config,
    input wire [31:0] light_config,
    output reg [31:0] result,
    output reg done
);

    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] INIT = 3'd1;
    localparam [2:0] CHECK = 3'd2;
    localparam [2:0] UPDATE = 3'd3;
    localparam [2:0] NEXT = 3'd4;
    localparam [2:0] DONE = 3'd5;

    reg [2:0] state;
    reg [31:0] count;
    reg [31:0] perm_counter;
    reg [3:0] photo_idx;
    reg [3:0] switch_idx;
    reg [1:0] perm [0:3];
    reg [1:0] avail [0:3];

    localparam [23:0] MOD = 24'd1000003;

    function [31:0] factorial;
        input [3:0] val;
        begin
            case (val)
                0, 1: factorial = 1;
                2: factorial = 2;
                3: factorial = 6;
                4: factorial = 24;
                default: factorial = 1;
            endcase
        end
    endfunction

    function get_bit;
        input [31:0] config;
        input [3:0] photo;
        input [3:0] sw;
        begin
            get_bit = config[photo * 4 + sw];
        end
    endfunction

    always @(*) begin
        reg [31:0] temp_counter = perm_counter;
        integer i, j, idx;
        for (i = 0; i < 4; i = i + 1) begin
            avail[i] = i;
        end
        for (i = 0; i < 4; i = i + 1) begin
            if (i < n) begin
                idx = temp_counter % (4 - i);
                temp_counter = temp_counter / (4 - i);
                perm[i] = avail[idx];
                for (j = idx; j < 3 - i; j = j + 1) begin
                    avail[j] = avail[j + 1];
                end
            end else begin
                perm[i] = 0;
            end
        end
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 32'd0;
            done <= 1'b0;
            count <= 32'd0;
            perm_counter <= 32'd0;
            photo_idx <= 4'd0;
            switch_idx <= 4'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        state <= INIT;
                        count <= 32'd0;
                        perm_counter <= 32'd0;
                    end
                end

                INIT: begin
                    photo_idx <= 4'd0;
                    switch_idx <= 4'd0;
                    state <= CHECK;
                end

                CHECK: begin
                    if (m == 0) begin
                        state <= UPDATE;
                    end else if (photo_idx >= m) begin
                        state <= UPDATE;
                    end else if (switch_idx >= n) begin
                        photo_idx <= photo_idx + 1;
                        switch_idx <= 4'd0;
                    end else begin
                        if (get_bit(switch_config, photo_idx, switch_idx) != 
                            get_bit(light_config, photo_idx, perm[switch_idx])) begin
                            state <= NEXT;
                        end else begin
                            switch_idx <= switch_idx + 1;
                        end
                    end
                end

                UPDATE: begin
                    count <= count + 1;
                    state <= NEXT;
                end

                NEXT: begin
                    perm_counter <= perm_counter + 1;
                    if (perm_counter >= factorial(n)) begin
                        result <= count % MOD;
                        state <= DONE;
                    end else begin
                        photo_idx <= 4'd0;
                        switch_idx <= 4'd0;
                        state <= CHECK;
                    end
                end

                DONE: begin
                    done <= 1'b1;
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end

endmodule