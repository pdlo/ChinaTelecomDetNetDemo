import pandas as pd
import random

def low_delay(path_df, s_delay):
    condition = path_df['path_delay'] < s_delay
    filtered_df = path_df[condition]
    max_idx = filtered_df['path_delay'].idxmax()
    # print(filtered_df)
    if filtered_df.empty:
        return -1
    else:
        return filtered_df.loc[max_idx, 'path_id']

def high_bandwidth(path_df, s_bandwidth):
    condition = path_df['path_left_bandwidth'] > s_bandwidth
    filtered_df = path_df[condition]
    min_idx = filtered_df['path_left_bandwidth'].idxmin()
    # print(filtered_df)
    if filtered_df.empty:
        return -1
    else:
        return filtered_df.loc[min_idx, 'path_id']


def high_reliability(path_df, s_delay, s_bandwidth):
    return random.randint(0, len(path_df)-1)

def calculate_forward(src_node, dst_node, node_bj_cal, node_gz_cal, s_cal):
    node_bj = 1
    node_gz = 2
    if s_cal < node_bj_cal and s_cal < node_gz_cal:
        if src_node == 'gz':
            return node_gz
        elif src_node == 'bf':
            return node_bj
        return 0
    elif s_cal >= node_bj_cal and s_cal < node_gz_cal:
        return node_gz
    elif s_cal < node_bj_cal and s_cal >= node_gz_cal:
        return node_bj
    elif s_cal >= node_bj_cal and s_cal >= node_gz_cal:
        return -1


def main():
    data_low_delay = [[1, 10], [2,50], [3,20]]
    path_df_low_delay = pd.DataFrame(data_low_delay, columns=['path_id', 'path_delay'])
    s_delay = 25
    path_id_low_delay = low_delay(path_df_low_delay, s_delay)
    print('path_id_low_delay: ', path_id_low_delay)

    data_high_bandwidth = [[1, 10], [2,50], [3,20]]
    path_df_high_bandwidth = pd.DataFrame(data_high_bandwidth, columns=['path_id', 'path_left_bandwidth'])
    s_bandwidth = 15
    path_id_high_bandwidth = high_bandwidth(path_df_high_bandwidth, s_bandwidth)
    print('path_id_high_bandwidth: ', path_id_high_bandwidth)

    data_high_reliability = [[1, 10, 10], [2, 50, 50], [3, 20, 20]]
    path_df_high_reliability = pd.DataFrame(data_high_reliability, columns=['path_id', 'path_delay', 'path_left_bandwidth'])
    s_delay = 25
    s_bandwidth = 15
    path_id_high_reliability = high_reliability(path_df_high_reliability, s_delay, s_bandwidth)
    print('path_id_high_reliability: ', path_id_high_reliability)

    src_node = 'gz'
    dst_node = 'bj'
    node_bj_cal = 20
    node_gz_cal = 15
    s_cal = 13
    node_id_calculate_forward = calculate_forward(src_node, dst_node, node_bj_cal, node_gz_cal, s_cal)
    print('node_id_calculate_forward: ', node_id_calculate_forward)


if __name__ == "__main__":
    main()