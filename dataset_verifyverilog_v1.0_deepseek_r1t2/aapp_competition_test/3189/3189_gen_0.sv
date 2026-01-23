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

    localparam [2:0] IDLE   = 3'b000;
    localparam [2:0] INIT   = 3'b001;
    localparam [2:0] CHECK  = 3'b010;
    localparam [2:0] NEXT   = 3'b011;
    localparam [2:0] UPDATE = 3'b100;
    localparam [2:0] DONE   = 3'b101;

    reg [2:0] state;
    reg [1:0] perm [0:3];
    reg [31:0] count;
    reg [31:0] perm_counter;
    reg [3:0] photo_idx;
    reg [3:0] switch_idx;
    
    localparam [23:0] MOD = 24'd1000003;

    function get_bit;
        input [31:0] cfg;
        input [3:0] photo;
        input [3:0] sw;
        begin
            get_bit = cfg[photo * 4 + sw];
        end
    endfunction

    function [31:0] factorial;
        input [3:0] val;
        begin
            case (val)
                4'd0, 4'd1: factorial = 32'd1;
                4'd2: factorial = 32'd2;
                4'd3: factorial = 32'd6;
                4'd4: factorial = 32'd24;
                default: factorial = 32'd1;
            endcase
        end
    endfunction

    reg [1:0] avail [0:3];
    reg [31:0] temp_counter;
    reg [3:0] temp_n;
    integer i_gen, idx_gen;
    integer j;

    always @(*) begin
        temp_counter = perm_counter;
        temp_n = n;
        for (i_gen = 0; i_gen < 4; i_gen = i_gen + 1) begin
            avail[i_gen] = i_gen[1:0];
        end
        for (i_gen = 0; i_gen < 4; i_gen = i_gen + 1) begin
            if (i_gen < temp_n) begin
                idx_gen = temp_counter % (4 - i_gen);
                temp_counter = temp_counter / (4 - i_gen);
                perm[i_gen] = avail[idx_gen];
                for (j = idx_gen; j < 3 - i_gen; j = j + 1) begin
                    avail[j] = avail[j+1];
                end
            end else begin
                perm[i_gen] = 2'd0;
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
                        count <= 32'd0;
                        perm_counter <= 32'd0;
                        state <= INIT;
                    end
                end

                INIT: begin
                    photo_idx <= 4'd0;
                    switch_idx <= 4'd0;
                    state <= CHECK;
                end

                CHECK: begin
                    if (m == 4'd0) begin
                        state <= UPDATE;
                    end else if (photo_idx >= m) begin
                        state <= UPDATE;
                    end else if (switch_idx >= n) begin
                        photo_idx <= photo_idx + 4'd1;
                        switch_idx <= 4'd0;
                    end else begin
                        if (get_bit(switch_config, photo_idx, switch_idx) != 
                            get_bit(light_config, photo_idx, perm[switch_idx])) begin
                            state <= NEXT;
                        end else begin
                            switch_idx <= switch_idx + 4'd1;
                        end
                    end
                end

                UPDATE: begin
                    count <= (count + 32'd1) % MOD;
                    state <= NEXT;
                end

                NEXT: begin
                    perm_counter <= perm_counter + 32'd1;
                    if (perm_counter + 32'd1 >= factorial(n)) begin
                        result <= count;
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