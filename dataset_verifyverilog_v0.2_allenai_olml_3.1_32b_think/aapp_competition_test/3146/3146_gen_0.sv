module pharmacy_sim (
    input clk,
    input rst_n,
    input start,
    input [63:0] in_drop_time [7:0],
    input [7:0] in_type [7:0],
    input [31:0] in_fill_time [7:0],
    input [2:0] valid_count,
    output reg [63:0] avg_in_store_time,
    output reg [63:0] avg_remote_time,
    output reg done
);

    parameter IDLE = 2'd0;
    parameter PROCESSING = 2'd1;
    parameter DONE = 2'd2;

    reg [1:0] state;
    reg [63:0] tech_free_time [3:0];
    reg [7:0] used [7:0];
    reg [63:0] drop_times [7:0];
    reg [7:0] types [7:0];
    reg [31:0] fill_times [7:0];
    reg [2:0] current_valid_count;
    reg [63:0] total_in_store;
    reg [63:0] total_remote;
    reg [2:0] count_in_store;
    reg [2:0] count_remote;
    reg [63:0] avg_in_store_time_reg;
    reg [63:0] avg_remote_time_reg;
    reg done_reg;
    reg [2:0] accum_count;

    assign done = done_reg;

    always @(posedge clk) begin
        if (!rst_n) begin
            state <= IDLE;
            tech_free_time <= 0;
            used <= 0;
            drop_times <= 0;
            types <= 0;
            fill_times <= 0;
            current_valid_count <= 0;
            total_in_store <= 0;
            total_remote <= 0;
            count_in_store <= 0;
            count_remote <= 0;
            avg_in_store_time_reg <= 0;
            avg_remote_time_reg <= 0;
            done_reg <= 0;
            accum_count <= 0;
        end else if (start == 1'b1) begin
            current_valid_count <= valid_count;
            if (valid_count >=1) begin
                drop_times[0] <= in_drop_time[0];
                types[0] <= in_type[0];
                fill_times[0] <= in_fill_time[0];
            end
            if (valid_count >=2) begin
                drop_times[1] <= in_drop_time[1];
                types[1] <= in_type[1];
                fill_times[1] <= in_fill_time[1];
            end
            if (valid_count >=3) begin
                drop_times[2] <= in_drop_time[2];
                types[2] <= in_type[2];
                fill_times[2] <= in_fill_time[2];
            end
            if (valid_count >=4) begin
                drop_times[3] <= in_drop_time[3];
                types[3] <= in_type[3];
                fill_times[3] <= in_fill_time[3];
            end
            if (valid_count >=5) begin
                drop_times[4] <= in_drop_time[4];
                types[4] <= in_type[4];
                fill_times[4] <= in_fill_time[4];
            end
            if (valid_count >=6) begin
                drop_times[5] <= in_drop_time[5];
                types[5] <= in_type[5];
                fill_times[5] <= in_fill_time[5];
            end
            if (valid_count >=7) begin
                drop_times[6] <= in_drop_time[6];
                types[6] <= in_type[6];
                fill_times[6] <= in_fill_time[6];
            end
            state <= PROCESSING;
            accum_count <=0;
            total_in_store <= 0;
            total_remote <= 0;
            count_in_store <= 0;
            count_remote <= 0;
        end else if (state == PROCESSING) begin
            if (accum_count < current_valid_count) begin
                if (types[accum_count] == 1) begin
                    total_in_store <= total_in_store + (fill_times[accum_count] - drop_times[accum_count]);
                    count_in_store <= count_in_store + 1;
                end else begin
                    total_remote <= total_remote + (fill_times[accum_count] - drop_times[accum_count]);
                    count_remote <= count_remote + 1;
                end
                accum_count <= accum_count + 1;
            end else begin
                state <= DONE;
            end
        end else if (state == DONE) begin
            if (count_in_store > 0) begin
                avg_in_store_time_reg <= total_in_store / count_in_store;
            end else begin
                avg_in_store_time_reg <= 0;
            end
            if (count_remote > 0) begin
                avg_remote_time_reg <= total_remote / count_remote;
            end else begin
                avg_remote_time_reg <= 0;
            end
            done_reg <= 1;
        end
    end

    assign avg_in_store_time = avg_in_store_time_reg;
    assign avg_remote_time = avg_remote_time_reg;
endmodule